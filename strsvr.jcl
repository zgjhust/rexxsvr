//STRSVR   JOB ,'TIME',MSGLEVEL=(1,1),MSGCLASS=X,NOTIFY=&SYSUID,
//         REGION=0M,SYSAFF=CD13                                
//STRSVR   EXEC PGM=IKJEFT01                                    
//SYSEXEC DD DSN=SM011.MVS.REXX,DISP=SHR                        
//CONFIG  DD DSN=SM011.MVS.REXX(CONFIG),DISP=SHR                
//SYSTSPRT DD SYSOUT=*                                          
//SYSIN  DD  DUMMY                                              
//SYSPRINT DD SYSOUT=*                                          
//SYSOUT   DD SYSOUT=*                                          
//SYSTSIN    DD *                                               
 %SOCKSVR                                                        
/*                                                              