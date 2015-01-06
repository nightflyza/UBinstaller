UPDATE `admins` SET 
`ChgConf` = '1',
`ChgPassword` = '1',
`ChgStat` = '1',
`ChgCash` = '1',
`UsrAddDel` = '1',
`ChgTariff` = '1',
`ChgAdmin` = '1' WHERE `login` = 'admin';
