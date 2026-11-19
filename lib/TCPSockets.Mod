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
  PROCEDURE UDPStart* ["TCPSockets_UDPStart"] (id: C.int; host: ARRAY OF C.char;
                            port, local, mode: C.int): C.int;
  PROCEDURE UDPSend* ["TCPSockets_UDPSend"] (id: C.int; VAR data: ARRAY OF C.char;
                       count: C.int; host: ARRAY OF C.char; port: C.int): C.int;
  (* 0 no packet, -1 error, otherwise datagram size plus one. Peer is IPv4 + network-order port. *)
  PROCEDURE UDPReceive* ["TCPSockets_UDPReceive"] (id: C.int; VAR data, peer: ARRAY OF C.char): C.int;
  PROCEDURE Listen* ["TCPSockets_Listen"] (port: C.int): C.int;
  PROCEDURE Accept* ["TCPSockets_Accept"] (): C.int;
  PROCEDURE StopListener* ["TCPSockets_StopListener"];
  PROCEDURE Close* ["TCPSockets_Close"] (id: C.int);
  PROCEDURE CloseAll* ["TCPSockets_CloseAll"];
END TCPSockets.
