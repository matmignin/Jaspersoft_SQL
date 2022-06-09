SELECT * FROM (
  -- Determine if Batch has a pkg lot/blister lot with\with out a COA
    SELECT 
      TESTID,BATCHNUMBER,PKGLOT,BLISTERLOT,PRODUCT,FORMULATIONID,CUSTOMER,
      RECEIVEDDATE AS DATERECEIVED, --PARAMETER for sorting
      FINISHEDDATE AS DATEFINISHED, --PARAMETER
      REQUESTSTATUS,
        -- if micro and pkg lot PKGLOT_TESTSTATUS
        AVG(CASE 
              WHEN (PKGLOT IS NOT NULL AND UPPER(TESTGROUP)='MICRO') 
              THEN TESTSTATUS 
            END)
          OVER (
            PARTITION BY BATCHNUMBER,PKGLOT ORDER BY PKGLOT NULLS FIRST
          ) AS PKGLOT_TESTSTATUS, -- PARAMETER
        -- if Micro with blister lot BLISTERLOT_TESTSTATUS
        AVG(CASE 
              WHEN (BLISTERLOT IS NOT NULL AND UPPER(TESTGROUP)='MICRO') 
               THEN TESTSTATUS
            END)  
          OVER (
            PARTITION BY BATCHNUMBER,BLISTERLOT ORDER BY BLISTERLOT NULLS FIRST
          ) AS BLISTERLOT_TESTSTATUS, --PARAMETER
        --if neither OTHER_TESTSTATUS
        AVG(CASE 
              WHEN (PKGLOT IS NULL AND BLISTERLOT IS NULL 
   AND UPPER(TESTGROUP)<>'STABILITY')  -- proposed change
             THEN TESTSTATUS
            END)
          OVER (
            PARTITION BY BATCHNUMBER ORDER BY PKGLOT NULLS FIRST
            ) AS OTHER_TESTSTATUS, --PARAMETER
        -- if there is COA report HAS_COFA
        SUM(CASE 
              WHEN (UPPER(TRIM(TESTID))='COA REPORT') 
              THEN 1 
                ELSE 0 
              END
            END)
          OVER (
            PARTITION BY BATCHNUMBER,PKGLOT,BLISTERLOT ORDER BY PKGLOT,BLISTERLOT NULLS FIRST
            ) AS HAS_COFA --PARAMETER
FROM
    (
      --merge all the Requests that have matching samples
      SELECT
         TR.REQUESTID,
         T.STATUS AS TESTSTATUS, --PARAMETER
         T.TESTGROUP,
         T.FINISHEDDATE,
         P.BATCHNUMBER, 
         P.GENERIC01  AS PKGLOT, --PARAMETER
         P.GENERIC04  AS BLISTERLOT, --PARAMETER
         P.PRODUCT,
         P.FORMULATIONID
         P.GENERIC02  AS CUSTOMER, --PARAMETER
         P.RECEIVEDDATE
      FROM
         TESTREQUEST TR,  --TABLE (TR) 
         TEST T, --TABLE (T) 
         REQUESTSAMPLE RS, --TABLE (RS) 
         PHYSICALSAMPLE P --TABLE (P) 
      WHERE TR.REQUESTGUID = T.REQUESTGUID
        AND TR.REQUESTGUID = RS.REQUESTGUID
        AND RS.SAMPLEGUID = P.SAMPLEGUID
        AND TR.STATUS <> 5000 AND TR.DELETION <> 'Y' -- 5000 = canceled
        AND T.STATUS <> 5000 AND T.DELETION <> 'Y'
        AND P.DELETION <> 'Y'
      UNION ALL
      -- select the tests from those requests 
      SELECT
         TR.REQUESTID,
         TR.STATUS AS REQUESTSTATUS,
         T.TESTID,
         T.STATUS AS TESTSTATUS,
         T.TESTGROUP,
         T.FINISHEDDATE,
         P.BATCHNUMBER,
         P.GENERIC01  AS PKGLOT,
         P.GENERIC04  AS BLISTERLOT,
         P.PRODUCT,
         P.FORMULATIONID
         P.GENERIC02  AS CUSTOMER,
         P.RECEIVEDDATE
      FROM
         TESTREQUEST TR, --TABLE (TR) 
         TEST T, --TABLE (T) 
         TESTSAMPLE TS, --TABLE (TS) 
         PHYSICALSAMPLE P --TABLE (P) 
      WHERE TR.REQUESTGUID = T.REQUESTGUID
        AND T.TESTGUID = TS.TESTGUID
        AND TS.SAMPLEGUID = P.SAMPLEGUID
        AND TR.STATUS <> 5000 AND TR.DELETION <> 'Y' -- not Canceled and not deleted
        AND T.STATUS <> 5000 AND T.DELETION <> 'Y' -- 5000 = Canceled
        AND P.DELETION <> 'Y'
    )
)
-- list the Batchens that have Pkg\blister lots and a Microbiological test and do not have a COA
WHERE REQUESTSTATUS=2000
  AND (PKGLOT_TESTSTATUS=1000 OR BLISTERLOT_TESTSTATUS=1000) -- 1000 = Finished
  AND (OTHER_TESTSTATUS=1000 OR OTHER_TESTSTATUS IS NULL)
  AND HAS_COFA=0
  AND TESTID='Microbiological'
-- order by whatever Parameter was selected or BATCHNUMBER by default
ORDER BY
  	CASE
	    WHEN $P{PARAM_SORT}= 'Batch' THEN BATCHNUMBER
    	WHEN $P{PARAM_SORT}= 'Date Received' THEN DATERECEIVED
    	WHEN $P{PARAM_SORT}= 'Customer' THEN CUSTOMER
    	ELSE BATCHNUMBER
    END
