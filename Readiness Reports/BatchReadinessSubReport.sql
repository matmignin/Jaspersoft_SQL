SELECT
    PRODUCT,BATCHNUMBER,PKGLOT,BLISTERLOT,
    CUSTOMER,
		RECEIVEDDATE,
    TESTGROUP,
    TESTID,
    DECODE(TESTSTATUS,5000,'CANCELED',800,'COMPLETED',1000,'FINISHED',500,'IN PROGRESS',100,'PENDING','UNKNOWN') AS TEST_STATUS,
    EXECUTESTARTDATE
FROM
    (SELECT
         TR.REQUESTID,
         TR.STATUS AS REQUESTSTATUS,
         T.TESTID,
         T.STATUS AS TESTSTATUS,
         T.TESTGROUP,
         T.EXECUTESTARTDATE,
         P.BATCHNUMBER,
         P.GENERIC01  AS PKGLOT,
         P.GENERIC04  AS BLISTERLOT,
         P.PRODUCT,
         P.GENERIC02  AS CUSTOMER,
         P.RECEIVEDDATE
    FROM
         TESTREQUEST TR,
         TEST T,
         REQUESTSAMPLE RS,
         PHYSICALSAMPLE P
    WHERE TR.REQUESTGUID = T.REQUESTGUID
        AND TR.REQUESTGUID = RS.REQUESTGUID
        AND RS.SAMPLEGUID = P.SAMPLEGUID
        AND TR.STATUS <> 5000 AND TR.DELETION <> 'Y'
        AND T.DELETION <> 'Y'
        AND P.DELETION <> 'Y'
    UNION ALL
    SELECT
         TR.REQUESTID,
         TR.STATUS AS REQUESTSTATUS,
         T.TESTID,
         T.STATUS AS TESTSTATUS,
         T.TESTGROUP,
         T.EXECUTESTARTDATE,
         P.BATCHNUMBER,
         P.GENERIC01  AS PKGLOT,
         P.GENERIC04  AS BLISTERLOT,
         P.PRODUCT,
         P.GENERIC02  AS CUSTOMER,
         P.RECEIVEDDATE
    FROM
         TESTREQUEST TR,
         TEST T,
         TESTSAMPLE TS,
         PHYSICALSAMPLE P
    WHERE TR.REQUESTGUID = T.REQUESTGUID
        AND T.TESTGUID = TS.TESTGUID
        AND TS.SAMPLEGUID = P.SAMPLEGUID
        AND TR.STATUS <> 5000 AND TR.DELETION <> 'Y'
        AND T.DELETION <> 'Y'
        AND P.DELETION <> 'Y'
    )
WHERE UPPER(TRIM(TESTID)) <> 'COA REPORT'
AND TESTSTATUS NOT IN (800,1000,5000)
AND RECEIVEDDATE >= $P{PARAM_RECEIVEDATE}
ORDER BY
  	CASE
	WHEN $P{PARAM_SORT}= 'Product' THEN PRODUCT
	WHEN $P{PARAM_SORT}= 'Batch' THEN BATCHNUMBER
	WHEN $P{PARAM_SORT}= 'Date Received' THEN RECEIVEDDATE
	WHEN $P{PARAM_SORT}= 'Customer' THEN CUSTOMER
	ELSE BATCHNUMBER
	END
	,TESTGROUP,TESTID