
--! Group timepoint and conditions into Batch Number
SELECT
   BATCHNAME,
   TIMEPOINT,
   STGCONDITIONNAME,
   LISTAGG(LWR_ID,',') WITHIN GROUP (ORDER BY BATCHNAME) AS lwrs
FROM
    ELNPROD.LMS_STABILITY_DATA
GROUP BY BATCHNAME, STGCONDITIONNAME, TIMEPOINT
ORDER BY BATCHNAME, STGCONDITIONNAME, TIMEPOINT;





SELECT
   BATCHNAME,
   TIMEPOINT,
   STGCONDITIONNAME,
   LISTAGG(LWR_ID,',') WITHIN GROUP (ORDER BY BATCHNAME) AS lwrs
FROM
    ELNPROD.LMS_STABILITY_DATA
GROUP BY BATCHNAME, STGCONDITIONNAME, TIMEPOINT
ORDER BY BATCHNAME, STGCONDITIONNAME, TIMEPOINT;


------Physical edit

SELECT
   BATCHNAME,
   STGCONDITIONNAME,
   TIMEPOINT,
   DATESCHEDULED,
   DATEPULLED
FROM
    ELNPROD.LMS_STABILITY_DATA
WHERE
    BATCHNAME LIKE '205-0258'
GROUP BY BATCHNAME, TIMEPOINT, STGCONDITIONNAME, DATESCHEDULED, DATEPULLED, CLIENTNAME
ORDER BY STGCONDITIONNAME;


-----
SELECT
*

--tr.resultid AS testing, ps.storagecondition AS storage_condition, ps.studyname AS study_name, tr.resultdate AS test_date, DECODE(tr.resulttype,NULL,NULL,DECODE(tr.requirement, NULL, t.requirement, tr.requirement)) AS specification_range, CASE WHEN tr.resulttype = 'NUMERIC' AND tr.status = 70 THEN tr.numericalresulttext||DECODE(tr.unit,NULL,NULL,' '||tr.unit) WHEN tr.resulttype IN ('LIST','TEXT') AND tr.status = 70 THEN tr.textresult||DECODE(tr.unit,NULL,NULL,' '||tr.unit) WHEN tr.status = 10 THEN 'pending' WHEN tr.resulttype = 'FREETEXT' THEN tr.textresult ELSE 'Not Tested' END AS result, sm.description AS method, tr.generic01   AS notebook_ref, ps.receiveddate AS phy_test_date, ps.studyname

--tr.resultid   AS testing,                   --{TESTING}
--ps.storagecondition AS storage_condition,
--ps.studyname AS study_name,
--tr.resultdate AS test_date,                 --{TEST_DATE}
--DECODE(
--  tr.resulttype,NULL,NULL,DECODE(tr.requirement, NULL, t.requirement, tr.requirement)
--  ) AS specification_range,                 --{SPECIFICATION_RANGE}
--CASE
--  WHEN tr.resulttype = 'NUMERIC' AND tr.status = 70 THEN
--    tr.numericalresulttext||DECODE(tr.unit,NULL,NULL,' '||tr.unit)
--  WHEN tr.resulttype IN ('LIST','TEXT') AND tr.status = 70 THEN
--    tr.textresult||DECODE(tr.unit,NULL,NULL,' '||tr.unit)
--  WHEN tr.status = 10 THEN
--    'pending'
--  WHEN tr.resulttype = 'FREETEXT' THEN
--    tr.textresult
--  ELSE
--    'Not Tested'
--  END AS result,
--sm.description AS method,                   --{METHOD}
--tr.generic01   AS notebook_ref,             --{NOTEBOOK_REF}
--ps.receiveddate AS phy_test_date,            --{PHY_TEST_DATE}
--ps.studyname

FROM (
    SELECT DISTINCT ps.sampleguid, ps.batchnumber, ps.formulationid
    FROM physicalsample ps                  --[ps] physicalsample
    JOIN testresult tr                      --[tr] testresult
      ON tr.sampleguid = ps.sampleguid
        AND tr.deletion = 'N'
    JOIN test t                             --[t] test
      ON t.testguid = tr.testguid
      AND UPPER(t.testgroup) = 'STABILITY'
        AND t.deletion = 'N'
    WHERE ps.batchnumber IS NOT NULL
      AND ps.deletion = 'N'
  ) psi                                     --[psi] physical sample's physical tests

JOIN testresult tr                          --[tr] testresult
  ON tr.sampleguid = psi.sampleguid
    AND tr.deletion = 'N'

JOIN test t                                 --[t] test
  ON t.testguid = tr.testguid
    AND UPPER(t.testgroup) = 'STABILITY'
      AND t.deletion = 'N'

LEFT JOIN smmethod sm                       --[sm] smmethod
  ON sm.methodid   = t.methodid
    AND sm.versionno = t.methodversionno
      AND sm.deletion  = 'N'

LEFT JOIN physicalsample ps                 --[ps] physicalsample
  ON ps.sampleguid = psi.sampleguid

LEFT JOIN specificationtestresult str       --[str] specificationtestresult
  ON str.specificationid = ps.specificationid
    AND str.versionno = ps.specificationversionno
    AND str.testid = t.testid
    AND str.resultid = tr.resultid
      AND str.deletion = 'N'

LEFT JOIN specificationtest st              --[st] specificationtest
  ON st.specificationid = str.specificationid
    AND st.versionno = str.versionno        -- fix new physical tests not showing up for active batches(1.3.2)
    AND st.testguid = str.testguid            AND st.deletion = 'N'

WHERE (st.deletion IS NULL
  OR (st.deletion IS NOT NULL AND st.deletion = 'N'))
  -- AND $X{ EQUAL ,psi.batchnumber, PHYSBATCHNUMBER}
    AND psi.batchnumber = '204-0225'
--    AND ps.studyname IS NOT NULL
--    AND sm.versiontype = 'A'
ORDER BY
    ps.storagecondition,
  DECODE(st.seqno,NULL,t.seqno,st.seqno),   --Fixed test order not folliwing sequence(1.3.2)
  DECODE(str.seqno,NULL,tr.sequencenumber,str.seqno)
