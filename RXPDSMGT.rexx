/* rexx */
pull cont
msgtxt = ''
crlf = '0D25'x
address tso
"alloc da('"strip(cont)"') f(indd) shr reuse"
if rc /= 0 then
  do
    msgid = 'RXH0008E'
    msgtxt = 'dataset allocate failed!'
  end
else
  do
    "execio * diskr indd (stem in. finis"
    if rc /=0 then
      do
        msgid = 'RXH0016E'
        msgtxt = 'I/O error while reading dataset!'
      end
    else
      do
        do ix = 1 to in.0
          msgtxt = msgtxt || in.ix || crlf
        end
        msgid = 'RXH0000I'
      end
  end
"free fi(indd)"
queue msgid 
queue msgtxt
return