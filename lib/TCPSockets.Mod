MODULE TCPSockets ["C"] EXTERNAL ["TCPSockets.c"];
  IMPORT C := CType;
  (* Host operations never wait for network or DNS on the simulator thread. *)
  PROCEDURE Start* ["TCPSockets_Start"] (id: C.int; host: ARRAY OF C.char; port: C.int): C.int;
  (* Poll: 1 connected, 0 pending, -1 failure. *)
  PROCEDURE Poll* ["TCPSockets_Poll"] (id: C.int): C.int;
  (* Send: positive count, 0 busy, -1 failure. *)
  PROCEDURE Send* ["TCPSockets_Send"] (id: C.int; VAR data: ARRAY OF C.char; offset, count: C.int): C.int;
  (* Receive: positive count, 0 busy, -1 closed/error. *)
  PROCEDURE Receive* ["TCPSockets_Receive"] (id: C.int; VAR data: ARRAY OF C.char; count: C.int): C.int;
  PROCEDURE Close* ["TCPSockets_Close"] (id: C.int);
  PROCEDURE CloseAll* ["TCPSockets_CloseAll"];
END TCPSockets.
