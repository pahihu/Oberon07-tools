#!/usr/bin/env python3
"""Count physical SLOC and optionally statements in Oberon-07 (Python 3.8+).

Usage:
  python3 oberon_sloc.py Module.Mod
  python3 oberon_sloc.py --statements src/
  python3 oberon_sloc.py --statements --json src/

Directory scans recurse over .Mod and .ob07, ignoring extension case.
Explicit files may have any extension. Overlapping paths are deduplicated.
Use --extensions .Mod,.ob07,.ob or --encoding latin-1 as needed.
Inputs must be plain-text source, not native Oberon rich-text documents.

Physical lines are classified as code, comment-only or blank. A mixed
code/comment line counts as code; whitespace-only lines count as blank,
even inside comments or hex strings. total = code + comment + blank.

With --statements, complete modules are parsed using the attached Oberon-07
productions, including MODULE*, leaf PROCEDURE* and interrupt handlers.
Interrupt brackets belong to procedure declarations, not procedure types.
FormalType = {ARRAY OF} qualident; inline PROCEDURE parameters are rejected.
Hex strings extend the supplied string rule to:
  hexString = "$" whitespace* hexDigit {hexDigit | whitespace} "$".
They may span lines and start with any 0-9/A-F digit. At least one digit is
required; no even-digit requirement is imposed. Nested (* ... *) comments
and double-quoted strings are supported; backslash is not an escape.

Assignments, calls, IF, CASE, WHILE, REPEAT and FOR each count once, plus
all nested statements. Procedure-tail RETURN counts once separately.
Declarations, empty statements, ELSIF/ELSE and FOR header initializations
add no statements. Calls inside expressions add no separate statements.
JSON includes per-kind counts. This is a syntax parser, not a semantic checker.

Exit status: 0 success; 1 input/lexical/syntax error; 2 command-line error or
no matching sources. Failed files are excluded from totals and listed as errors.
"""

import argparse
from bisect import bisect_right
from collections import Counter
from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import re
import sys


_RESERVED = set('ARRAY BEGIN BY CASE CONST DIV DO ELSE ELSIF END FALSE FOR IF '
                'IMPORT IN IS MOD MODULE NIL OF OR POINTER PROCEDURE RECORD '
                'REPEAT RETURN THEN TO TRUE TYPE UNTIL VAR WHILE'.split())
_STATEMENT_KINDS = ('assignment', 'call', 'if', 'case', 'while', 'repeat', 'for', 'return')
_ATOM = re.compile(
    r'(?P<real>[0-9]+\.(?!\.)[0-9]*(?:E[+-]?[0-9]+)?)|'
    r'(?P<hex>[0-9][0-9A-F]*[HX])|(?P<integer>[0-9]+)|'
    r'(?P<ident>[A-Za-z][A-Za-z0-9]*)|'
    r'(?P<symbol>:=|<=|>=|\.\.|[+\-*/=\#<>~&.,;:|()\[\]{}^])'
)


@dataclass
class Counts:
    code: int = 0
    comment: int = 0
    blank: int = 0

    @property
    def total(self):
        return self.code + self.comment + self.blank

    def record(self):
        return dict(asdict(self), total=self.total)


def normalize(text):
    if text.startswith('\ufeff'):
        text = text[1:]
    return text.replace('\r\n', '\n').replace('\r', '\n')


class Lexer:
    """One scanner supplies tokens and physical line classification."""
    def __init__(self, text):
        self.text = normalize(text)
        self.line_starts = [0] + [m.end() for m in re.finditer('\n', self.text)]
        self.code_lines = set()
        self.tokens = []

    def error(self, message, offset):
        row = bisect_right(self.line_starts, offset) - 1
        column = offset - self.line_starts[row] + 1
        raise ValueError('{} at line {}, column {}'.format(message, row + 1, column))

    def emit(self, start, end, kind):
        value = self.text[start:end]
        row = bisect_right(self.line_starts, start) - 1
        for delta, part in enumerate(value.split('\n')):
            if part.strip():
                self.code_lines.add(row + delta)
        self.tokens.append((value, kind, start))

    def scan(self):
        text = self.text
        i = 0
        while i < len(text):
            if text[i].isspace():
                i += 1
                continue
            if text.startswith('(*', i):
                openings = [i]
                i += 2
                while openings and i < len(text):
                    if text.startswith('(*', i):
                        openings.append(i)
                        i += 2
                    elif text.startswith('*)', i):
                        openings.pop()
                        i += 2
                    else:
                        i += 1
                if openings:
                    self.error('unterminated comment', openings[-1])
                continue
            if text.startswith('*)', i):
                self.error('unmatched *)', i)
            start = i
            if text[i] == '"':
                i += 1
                while i < len(text) and text[i] not in ('"', '\n'):
                    i += 1
                if i == len(text) or text[i] != '"':
                    self.error('unterminated quoted string', start)
                i += 1
                self.emit(start, i, 'string')
            elif text[i] == '$':
                i += 1
                digits = 0
                while i < len(text) and text[i] != '$':
                    if text[i] in '0123456789ABCDEF':
                        digits += 1
                    elif not text[i].isspace():
                        self.error('invalid hexadecimal string character {!r}'.format(text[i]), i)
                    i += 1
                if i == len(text):
                    self.error('unterminated hexadecimal string', start)
                if not digits:
                    self.error('empty hexadecimal string', start)
                i += 1
                self.emit(start, i, 'hexstring')
            else:
                match = _ATOM.match(text, i)
                if match is None:
                    self.error('invalid character {!r}'.format(text[i]), i)
                i = match.end()
                self.emit(start, i, match.lastgroup)
        self.tokens.append(('<EOF>', 'eof', len(text)))
        lines = text.split('\n')
        if lines[-1] == '':
            lines.pop()
        counts = Counts()
        for row, line in enumerate(lines):
            if not line.strip():
                counts.blank += 1
            elif row in self.code_lines:
                counts.code += 1
            else:
                counts.comment += 1
        return self.tokens, counts


def count_source(text):
    """Count physical lines with the same lexer used for statement counts."""
    return Lexer(text).scan()[1]


def tokenize(text):
    return Lexer(text).scan()[0]


class StatementParser:
    def __init__(self, text, tokens=None):
        self.text = normalize(text)
        self.tokens = tokenize(self.text) if tokens is None else tokens
        self.pos = 0
        self.counts = Counter({kind: 0 for kind in _STATEMENT_KINDS})

    def peek(self):
        return self.tokens[self.pos][0]

    def accept(self, token):
        if self.peek() == token:
            self.pos += 1
            return True
        return False

    def expect(self, token):
        if not self.accept(token):
            self.error('expected ' + token)

    def error(self, message):
        token, _, offset = self.tokens[self.pos]
        line = self.text.count('\n', 0, offset) + 1
        column = offset - self.text.rfind('\n', 0, offset)
        raise ValueError('{} at line {}, column {}; found {!r}'.format(message, line, column, token))

    def is_ident(self):
        token, kind, _ = self.tokens[self.pos]
        return kind == 'ident' and token not in _RESERVED

    def ident(self):
        if not self.is_ident():
            self.error('expected identifier')
        value = self.peek()
        self.pos += 1
        return value

    def qualident(self):
        self.ident()
        if self.accept('.'):
            self.ident()

    def identdef(self):
        self.ident()
        self.accept('*')

    def identlist(self):
        self.identdef()
        while self.accept(','):
            self.identdef()

    def parse(self):
        self.expect('MODULE')
        self.accept('*')
        name = self.ident()
        self.expect(';')
        if self.accept('IMPORT'):
            while True:
                self.ident()
                if self.accept(':='):
                    self.ident()
                if not self.accept(','):
                    break
            self.expect(';')
        self.declarations()
        if self.accept('BEGIN'):
            self.sequence()
        self.expect('END')
        if self.ident() != name:
            self.error('module closing name differs from opening name')
        self.expect('.')
        self.expect('<EOF>')
        return dict(self.counts)

    def declarations(self):
        if self.accept('CONST'):
            while self.is_ident():
                self.identdef()
                self.expect('=')
                self.expression()
                self.expect(';')
        if self.accept('TYPE'):
            while self.is_ident():
                self.identdef()
                self.expect('=')
                self.type()
                self.expect(';')
        if self.accept('VAR'):
            while self.is_ident():
                self.identlist()
                self.expect(':')
                self.type()
                self.expect(';')
        while self.accept('PROCEDURE'):
            self.accept('*')  # Leaf marker precedes the name; export follows it.
            name = self.ident()
            self.accept('*')
            if self.peek() == '[':
                self.interrupt_vector()
            elif self.peek() == '(':
                self.formals()
            self.expect(';')
            self.declarations()
            if self.accept('BEGIN'):
                self.sequence()
            if self.accept('RETURN'):
                self.counts['return'] += 1
                self.expression()
            self.expect('END')
            if self.ident() != name:
                self.error('procedure closing name differs from opening name')
            self.expect(';')

    def interrupt_vector(self):
        self.expect('[')
        token, kind, _ = self.tokens[self.pos]
        if kind == 'integer' or (kind == 'hex' and token.endswith('H')):
            self.pos += 1
        elif self.is_ident():
            self.qualident()
        else:
            self.error('expected interrupt vector integer or qualified identifier')
        self.expect(']')

    def formals(self):
        self.expect('(')
        if self.peek() != ')':
            while True:
                self.accept('VAR')
                self.ident()
                while self.accept(','):
                    self.ident()
                self.expect(':')
                while self.accept('ARRAY'):
                    self.expect('OF')
                self.qualident()
                if not self.accept(';'):
                    break
        self.expect(')')
        if self.accept(':'):
            self.qualident()

    def type(self):
        if self.accept('ARRAY'):
            self.expression()
            while self.accept(','):
                self.expression()
            self.expect('OF')
            self.type()
        elif self.accept('RECORD'):
            if self.accept('('):
                self.qualident()
                self.expect(')')
            if self.is_ident():
                while True:
                    self.identlist()
                    self.expect(':')
                    self.type()
                    if not self.accept(';'):
                        break
                    # The supplied grammar requires a field after each ';'.
            self.expect('END')
        elif self.accept('POINTER'):
            self.expect('TO')
            self.type()
        elif self.accept('PROCEDURE'):
            if self.peek() == '(':
                self.formals()
        else:
            self.qualident()

    def expression(self):
        self.simple()
        if self.peek() in ('=', '#', '<', '<=', '>', '>=', 'IN', 'IS'):
            self.pos += 1
            self.simple()

    def simple(self):
        if self.peek() in ('+', '-'):
            self.pos += 1
        self.term()
        while self.peek() in ('+', '-', 'OR'):
            self.pos += 1
            self.term()

    def term(self):
        self.factor()
        while self.peek() in ('*', '/', 'DIV', 'MOD', '&'):
            self.pos += 1
            self.factor()

    def factor(self):
        if self.tokens[self.pos][1] in ('integer', 'real', 'hex', 'string', 'hexstring') or self.peek() in ('NIL', 'TRUE', 'FALSE'):
            self.pos += 1
        elif self.accept('~'):
            self.factor()
        elif self.accept('('):
            self.expression()
            self.expect(')')
        elif self.accept('{'):
            if self.peek() != '}':
                while True:
                    self.expression()
                    if self.accept('..'):
                        self.expression()
                    if not self.accept(','):
                        break
            self.expect('}')
        elif self.is_ident():
            self.designator()
            self.actuals()
        else:
            self.error('expected expression')

    def designator(self):
        self.qualident()
        while True:
            if self.accept('.'):
                self.ident()
            elif self.accept('['):
                self.expression()
                while self.accept(','):
                    self.expression()
                self.expect(']')
            elif self.accept('^'):
                pass
            elif self.peek() == '(':
                # A type guard and a one-identifier argument are syntactically
                # ambiguous. Treat (qualident) as a guard; statement totals
                # are identical, and following selectors remain parseable.
                saved = self.pos
                self.pos += 1
                if self.is_ident():
                    self.qualident()
                    if self.accept(')'):
                        continue
                self.pos = saved
                break
            else:
                break

    def actuals(self):
        if self.accept('('):
            if self.peek() != ')':
                self.expression()
                while self.accept(','):
                    self.expression()
            self.expect(')')

    def sequence(self):
        self.statement()
        while self.accept(';'):
            self.statement()

    def statement(self):
        token = self.peek()
        if self.is_ident():
            self.designator()
            if self.accept(':='):
                self.counts['assignment'] += 1
                self.expression()
            else:
                self.counts['call'] += 1
                self.actuals()
        elif token == 'IF' or token == 'WHILE':
            self.pos += 1
            self.counts[token.lower()] += 1
            delimiter = 'THEN' if token == 'IF' else 'DO'
            self.expression()
            self.expect(delimiter)
            self.sequence()
            while self.accept('ELSIF'):
                self.expression()
                self.expect(delimiter)
                self.sequence()
            if token == 'IF' and self.accept('ELSE'):
                self.sequence()
            self.expect('END')
        elif self.accept('REPEAT'):
            self.counts['repeat'] += 1
            self.sequence()
            self.expect('UNTIL')
            self.expression()
        elif self.accept('FOR'):
            self.counts['for'] += 1
            self.ident()
            self.expect(':=')
            self.expression()
            self.expect('TO')
            self.expression()
            if self.accept('BY'):
                self.expression()
            self.expect('DO')
            self.sequence()
            self.expect('END')
        elif self.accept('CASE'):
            self.counts['case'] += 1
            self.expression()
            self.expect('OF')
            while True:
                if self.peek() not in ('|', 'END'):
                    while True:
                        self.label()
                        if self.accept('..'):
                            self.label()
                        if not self.accept(','):
                            break
                    self.expect(':')
                    self.sequence()
                if not self.accept('|'):
                    break
            self.expect('END')
        elif token not in (';', 'END', 'ELSIF', 'ELSE', 'UNTIL', '|', 'RETURN'):
            self.error('expected statement')
        # Empty statements count as zero.

    def label(self):
        kind = self.tokens[self.pos][1]
        if kind in ('integer', 'hex', 'string', 'hexstring'):
            self.pos += 1
        else:
            self.qualident()


def count_statements(text):
    """Return per-kind counts for one complete module; no semantic checks."""
    return StatementParser(text).parse()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('paths', nargs='+', type=Path)
    parser.add_argument('--extensions', default='.Mod,.ob07', help='comma-separated directory scan extensions')
    parser.add_argument('--encoding', default='utf-8-sig', help='source encoding (default: utf-8-sig)')
    parser.add_argument('--json', action='store_true', help='emit machine-readable JSON')
    parser.add_argument('--statements', action='store_true', help='also count logical statements in complete modules')
    args = parser.parse_args(argv)
    extensions = {'.' + e.strip().lstrip('.').lower() for e in args.extensions.split(',') if e.strip().lstrip('.')}
    if not extensions:
        parser.error('--extensions must contain at least one extension')
    files = {}
    errors = []

    def add_error(message):
        errors.append(str(message))

    def add_file(path):
        try:
            files.setdefault(path.resolve(strict=True), path)
        except OSError as exc:
            add_error('{}: {}'.format(path, exc))

    for path in args.paths:
        if path.is_file():
            add_file(path)
        elif path.is_dir():
            for root, directories, names in os.walk(path, followlinks=False, onerror=add_error):
                directories.sort()
                for name in sorted(names):
                    candidate = Path(root) / name
                    if candidate.suffix.lower() in extensions:
                        add_file(candidate)
        else:
            add_error('{}: not a file or directory'.format(path))

    rows = []
    statement_totals = Counter({kind: 0 for kind in _STATEMENT_KINDS})
    total = Counts()
    for canonical, display in sorted(files.items(), key=lambda item: str(item[1])):
        try:
            text = canonical.read_text(encoding=args.encoding)
            lexer = Lexer(text)
            tokens, counts = lexer.scan()
            statement_counts = StatementParser(lexer.text, tokens).parse() if args.statements else None
        except (OSError, UnicodeError, LookupError, ValueError, RecursionError) as exc:
            add_error('{}: {}'.format(display, exc))
            continue
        rows.append(dict(file=str(display), **counts.record()))
        if args.statements:
            rows[-1].update(statements=sum(statement_counts.values()), statement_counts=statement_counts)
            statement_totals.update(statement_counts)
        total.code += counts.code
        total.comment += counts.comment
        total.blank += counts.blank

    if not files and not errors:
        parser.error('no matching source files found')
    total_record = total.record()
    if args.statements:
        total_record.update(statements=sum(statement_totals.values()), statement_counts=dict(statement_totals))
    if args.json:
        print(json.dumps(dict(files=rows, total=total_record, errors=errors), indent=2))
    else:
        header = '{:>9} {:>9} {:>9} {:>9}'.format('code', 'comment', 'blank', 'total')
        print(header + (' {:>10}'.format('statements') if args.statements else '') + '  file')
        for row in rows + [dict(file='TOTAL', **total_record)]:
            line = '{code:9d} {comment:9d} {blank:9d} {total:9d}'.format(**row)
            if args.statements:
                line += ' {statements:10d}'.format(**row)
            print(line + '  ' + row['file'])
        for error in errors:
            print('error: ' + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
