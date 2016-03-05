/* rexx */

/*-------------------------------------------------------------------*/
/* Name:        socksvr                                              */
/* Description: a socket server                                      */
/* Function:                                                         */
/*   read config dataset and set related configuration,include:      */
/*     server port, server version                                   */
/*     logging and auditing parameters                               */
/*     packet processing rexx handler definition                     */
/*   packet processing rexx handler includes:                        */
/*     pds member read and return the content                        */
/*     tso command execution and return result                       */
/*     mvs command execution and return result                       */
/*-------------------------------------------------------------------*/
signal on halt

/* global varaibles */
cltsocks = ''
pkt_type_len = 8  /* first 7 bytes is pkt type for req or msg id for resp */
pkt_contlen_len =10   /* following 10 bytes is content length */
pkt_headlen = pkt_type_len + pkt_contlen_len

/* read server parameters to stem config. */
call parseconfig
/* initialize server to listen for client sockets */
call initserver

do forever
  srv = Socket('Select','READ' sockid cltsocks 'WRITE' cltsocks 'EXCEPTION',,
               config.TIMEOUT)
  parse upper var srv 'READ' rlist 'WRITE' wlist 'EXCEPTION' xlist
  call do_accept
  call do_write
  call do_read

end

/*-------------------------------------------------------------------*/
/* Name:        do_accept                                            */
/* Description: proc to accept new client socket                     */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
do_accept:
 /* If a connection is coming in, then it comes in as a read request
     to the incoming socket.  In other words, the client is writing
     and we are reading.   */
if inlist(sockid,rlist) then  /* Read request on our listen socket?  */
  do
    srv = Socket('Accept',sockid)   /* Accept it, it gets new sock */
    parse var srv src cltsockid . newport newip
    if config.VERBOSE then
      say 'Accept returned ===>' srv
    if src = 0 then
      do
         cltsocks = addsock(cltsockid,cltsocks) /* Add to clt array */
         ts = date() time()
         say ts 'Connection received from port='newport 'ip='newip,
             'Socket('cltsockid')'
      end
    else
      do
        ts = date() time()
        parse var srv src errtxt
        say ts 'Accept Error:' errtxt
      end
    srv = Socket('Socketsetstatus')
    parse var srv src . status
    ts = date() time()
    say ts 'Current socket status:' status
    /*  Communicate in ASCII  */
    srv = Socket('Setsockopt',cltsockid,'SOL_SOCKET','SO_ASCII','ON')
    parse var srv src
    if config.VERBOSE then
      say 'Setsockopt ===>' srv
    /*  Non-Blocking IO      */
    srv = Socket('Ioctl',cltsockid,'FIONBIO','ON' )
    parse var srv src
    if config.VERBOSE then
      say 'Ioctl      ===>' srv

  end
return

/*-------------------------------------------------------------------*/
/* Name:        do_read                                              */
/* Description: proc to read from client socket                      */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
do_read:
do idx = 1 to words(rlist)
  if words(rlist) = 0 then Leave
  cltsockid = word(rlist,idx)
  if cltsockid = sockid then iterate /* Ignore Listening Socket */
     /* Initialize sockinfos if necessary */
  if symbol('sockinfos.cltsockid.rbuf') = 'LIT' then
    do
      sockinfos.cltsockid.rbuf = ''
    end
  /* read until no data or connection closed */
  do forever
    srv = Socket('Recv',cltsockid)
    parse var srv src len data  /* Ignore 35 & 36 for nonblocking. */
    if src = 35 then leave      /* 35 is EWOULDBLOCK. Nothing to receive. */
    if src = 36 then leave      /* 36 is EINPROGRESS. Nothing to receive.  */
    if src = 0 & len = 0 then   /* Zero length means that the client */
      do                        /* has disconnected.                 */
        call closesock cltsockid
        return 
      end
    if src = 0 then          /* Return code is zero and there is data... */
      do
        if config.VERBOSE then
           say 'Received ('cltsockid'):' len 'bytes from client'
        sockinfos.cltsockid.rbuf = sockinfos.cltsockid.rbuf || data
      end
    if src > 0 & src <> 35 & src <>36 then
      do
        say 'Read Error ==>' srv
        call closesock cltsockid
        return
      end
  end
  
  call processPacket cltsockid
  /* end read a socket */
end
return

/*-------------------------------------------------------------------*/
/* Name:        do_write                                             */
/* Description: proc to write to client socket                       */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
do_write:

do ix = 1 to words(wlist)
  cltsockid = word(wlist,idx)
  if symbol('sockinfos.cltsockid.wbuf') = 'LIT' then iterate
  if length(sockinfos.cltsockid.wbuf) = 0 then iterate
  do forever
    if sockinfos.cltsockid.wbuf = '' then leave
    srv = Socket('send', cltsockid, sockinfos.cltsockid.wbuf)
    parse var srv src len
    if src = 35 then leave      /* 35 is EWOULDBLOCK. */
    if src = 36 then leave      /* 36 is EINPROGRESS. */
    if src = 0 then
      do
        if config.VERBOSE then
          say 'Sended ('cltsockid'):' len 'bytes to client'  
        sockinfos.cltsockid.wbuf = substr(sockinfos.cltsockid.wbuf,,
                len+1, length(sockinfos.cltsockid.wbuf)-len)
      end
    if src > 0 & src <> 35 & src <> 36 then
      do
        say 'Send Error ==>' srv
        call closesock cltsockid
        return
      end
  end
end
return

/*-------------------------------------------------------------------*/
/* Name:        processPacket                                       */
/* Description: proc to process packet recieved from client socket  */
/* Args:        client socket id                                     */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
processPacket:

arg csock 
do forever
  buflen = length(sockinfos.csock.rbuf)
  if buflen < pkt_headlen then leave
  contlen = substr(sockinfos.csock.rbuf, pkt_type_len+1, pkt_contlen_len)
  if datatype(contlen) /='NUM' then 
    do
      /* invalid packet received, close connection,some kind of rude */
      sockinfos.csock.rbuf = ''
      say 'invalid packet,content length error,dropped!'
      call closesock csock
      return
    end
  if buflen < contlen + pkt_headlen then leave
  pkt_type = translate(substr(sockinfos.csock.rbuf, 1, pkt_type_len))
  pkt_cont = substr(sockinfos.csock.rbuf, pkt_headlen+1, contlen)
  if buflen <= pkt_headlen + contlen then
    do  
      sockinfos.csock.rbuf = ''
      if buflen < pkt_headlen + contlen then
        do
          /* invalid packet received, close connection,some kind of rude */
          say 'invalid packet length!sock('csock')'
          call closesock csock
          return
        end
    end
  else
    sockinfos.csock.rbuf = substr(sockinfos.csock.rbuf,,
                pkt_headlen+contlen+1,buflen-pkt_headlen-contlen)
  if symbol('sockinfos.csock.wbuf') = 'LIT' then 
    sockinfos.csock.wbuf = ''
  if symbol('config.pkt_type') = 'LIT' then
    do
      wmsgid = 'RXS0002E'
      wcont = 'packet handler not found,packet dropped!'
    end
  else
    do
      queue pkt_cont
      interpret 'call' config.pkt_type
      if queued() /=2 then 
        do
          wcont = 'packet handler interface error!Expected 2 push!'
          if queued() = 1 then parse pull wmsgid
          else
            wmsgid = 'RXS0001E'
        end
      else
        do
          parse pull wmsgid
          parse pull wcont
        end
    end
  
  resp = substr(wmsgid,1,pkt_type_len,' ')||,
                 substr(length(wcont),1,pkt_contlen_len,' ')||wcont
  sockinfos.csock.wbuf = sockinfos.csock.wbuf || resp
  do forever
    if sockinfos.csock.wbuf = '' then leave
    srv = Socket('send', csock, sockinfos.csock.wbuf)
    parse var srv src len
    if src = 35 then leave      /* 35 is EWOULDBLOCK. */
    if src = 36 then leave      /* 36 is EINPROGRESS. */
    if src = 0 then
      do
        if config.VERBOSE then
          say 'Sended ('cltsockid'):' len 'bytes to client'  
        sockinfos.csock.wbuf = substr(sockinfos.csock.wbuf,,
                len+1, length(sockinfos.csock.wbuf)-len)
      end   
    if src > 0 & src <> 35 & src <> 36 then
      do
        say 'Send Error ==>' srv
        call closesock cltsockid
        return
      end
  end

end
return

/*-------------------------------------------------------------------*/
/* Name:        parseconfig                                          */
/* Description: proc to parse server parameters                      */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
parseconfig:

address tso
"execio * diskr CONFIG (stem in. finis"
do ix = 1 to in.0
  parse upper var in.ix name "=" value .
  name = strip(name)
  value = strip(value)
  config.name = value
end
"free fi(CONFIG)"

/* handle default parameters */
if symbol('config.PORT') = 'LIT' | datatype(config.PORT) /= 'NUM' then
  config.PORT = 5000
if symbol('config.MAXSOCKS') = 'LIT' | datatype(config.MAXSOCKS) /='NUM' then
  config.MAXSOCKS = 50
if symbol('config.TIMEOUT') = 'LIT' | datatype(config.TIMEOUT) /='NUM' then
  config.TIMEOUT = 600
if symbol('config.VERBOSE') = 'LIT' | config.VERBOSE = 'OFF' then
  config.VERBOSE = 0
else
  config.VERBOSE = 1
if symbol('config.DOTRACE') = 'LIT' | config.DOTRACE = 'OFF' then
  trace O
else
  trace i
return

/*-------------------------------------------------------------------*/
/* Name:        initserver                                           */
/* Description: proc to initialize server                            */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
initserver:
say 'Server' config.SERVER 'version' config.VERSION 'is initializing.'
startDateTime = date() time()
/* Initialize */
srv = Socket('Initialize', config.SERVER, config.MAXSOCKS)
if config.VERBOSE then
  say 'Server Initialized ===>' srv
srv = Socket('GetHostId')
parse var srv src ipaddress
if config.VERBOSE then
  say 'gethostid retd ===>' srv
srv = Socket('Socket')   /* Get Server socket for listen */
parse var srv src sockid
if config.VERBOSE then
  say 'socket   retd   ===>' srv
if src > 0 then signal bye
srv = Socket('Gethostname')
parse var srv src hostname
if config.VERBOSE then
  say 'gethnm   retd   ===>' srv
srv = Socket('Gethostbyname',hostname)
parse var srv src hostipaddress
if config.VERBOSE then
  say 'gethbynm retd   ===>' srv
/* Set Socket Options:  Reuse, NoLinger, NoBlock */
srv = Socket('Setsockopt',sockid,'SOL_SOCKET','SO_REUSEADDR','ON')
parse var srv src
if config.VERBOSE then
  say 'Setsockopt ===>' srv
srv = Socket('Setsockopt',sockid,'SOL_SOCKET','SO_LINGER','OFF')
parse var srv src
if config.VERBOSE then
  say 'Setsockopt ===>' srv
srv = Socket('Ioctl',sockid,'FIONBIO','ON' )
parse var srv src rest
if config.VERBOSE then
  say 'Ioctl     ===>' srv
/* Bind to Port/IpAddress */
srv = Socket('Bind',sockid,'AF_INET' config.PORT ipaddress)
parse var srv src
if config.VERBOSE then
  say 'Bind retd ===>' srv
If Src > 0
  Then Do
    Say 'Bind Failed with error:' src
    signal bye
End
/* Listen for incoming connections.  Queue max of 10.  */
srv = Socket('Listen',sockid,20)
parse var srv src
if config.VERBOSE then
  say 'listen    ===>' srv
if src > 0 then signal bye
srv = Socket('Getsockname',sockid)
parse var srv src . p i
if src = 0 Then do
  ts = date() time()
  say ts 'Server Initialized.  Listening on port='p 'ip='i
end
else signal bye
return

/*-------------------------------------------------------------------*/
/* Name:        bye                                                  */
/* Description: proc to close sockets and exit                       */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*-------------------------------------------------------------------*/
bye:
ts = date() time()
say ts 'Server shutdown command received.  Shutting down...'
/* Close all remaining open sockets */
do ix = 1 to words(cltsocks)
  if words(cltsocks) = 0 then leave
  call closesock word(cltsocks,ix) "NOREMOVE"
end
call closesock sockid   /* Close listening socket */
call Socket('Terminate')
Exit 0

/*-------------------------------------------------------------------*/
/* Name:        closesock                                            */
/* Description: Proc to close a socket                               */
/* Args:        socket,flag to indicate whether to remove from array */
/* Returns:     n/a                                                  */
/*                                                                   */
/*-------------------------------------------------------------------*/
closesock:
arg cltsockid removefl
srv = Socket('Close',cltsockid)
if config.VERBOSE then
  say 'Close returned ===>' srv
ts = date() time()
say ts 'Closing Connection on socket' cltsockid
if removefl <> "NOREMOVE"  /* Ok, this flag was a kludge, but   */
  then                     /* it was the easiest solution....   */
    cltsocks = delsock(cltsockid,cltsocks)
drop sockinfos.cltsockid.rbuf
drop sockinfos.cltsockid.wbuf
return

/*-------------------------------------------------------------------*/
/* Name:        addsock                                              */
/* Description: Function to maintain client socket array             */
/* Args:        socket, array                                        */
/* Returns:     new array                                            */
/*                                                                   */
/*-------------------------------------------------------------------*/
addsock: procedure
  arg newsock,socklist
  if wordpos(newsock,socklist) = 0
    then
      socklist = socklist newsock
return socklist

/*-------------------------------------------------------------------*/
/* Name:        delsock                                              */
/* Description: Function to maintain client socket array             */
/* Args:        socket, array                                        */
/* Returns:     new array                                            */
/*                                                                   */
/*-------------------------------------------------------------------*/
delsock: procedure
arg oldsock,socklist
if wordpos(oldsock,socklist) > 0
  then do
    templist = ''
    do ix = 1 to words(socklist)
      if oldsock <> word(socklist,ix)
        then
          templist = templist word(socklist,ix)
    end
    socklist = templist
end
return socklist

/*-------------------------------------------------------------------*/
/* Name:        inlist                                               */
/* Description: Function to test whether a socket is in a particular */
/*              list of sockets                                      */
/* Args:        socket, array                                        */
/* Returns:     TRUE, FALSE                                          */
/*                                                                   */
/*-------------------------------------------------------------------*/
inlist: procedure
arg sock, socklist
do ix = 1 to words(socklist)
  if words(socklist) = 0
    then return 0
  if sock = word(socklist,ix)
    then return 1
end
return 0

/*-------------------------------------------------------------------*/
/* Name:        halt                                                 */
/* Description: Signals bye when exec is halted (ATTN)               */
/* Args:        n/a                                                  */
/* Returns:     n/a                                                  */
/*                                                                   */
/*-------------------------------------------------------------------*/
halt:
signal bye