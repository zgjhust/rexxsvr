/* rexx */
pull cont
resp = ''
msgtxt = ''
crlf = '0D25'x
rc = isfcalls('on')
address sdsf "isfexec " ||"'"|| strip(cont)||"'"
select
  when rc = 0 then
    do
      do ix = 1 to isfulog.0
        msgtxt = msgtxt || isfulog.ix ||crlf
      end
      msgid = 'RXH0000I'
    end
  when rc = 8 then
    do
      msgid = 'RXH0008E'
      msgtxt = 'An incorrect or invalid parameter '
                   'was specified for an option or command.'
    end
  when rc = 12 then
    do
      msgid = 'RXH0012E'
      msgtxt = 'A syntax error occurred parsing a host environment command.'
    end
  when rc = 16 then
    do
      msgid = 'RXH0016E'
      msgtxt = 'The user is not authorized to invoke SDSF.'
    end
  when rc = 20 then
    do
      msgid = 'RXH0020E'
      msgtxt = 'A request failed due to an environmental error.'
    end
  otherwise
    do
      msgid = 'RXH0024E'
      msgtxt = 'Insufficient storage was available to complete a request.'
    end
end
queue substr(msgid,1,10,' ')
queue msgtxt
return
