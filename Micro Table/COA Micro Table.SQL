SELECT tr.resultid AS testing,
  CASE WHEN tr.resulttype = 'LIST'
    THEN
      --if t.requirement is blank THEN specification_range=trr.listvalue, ELSE =trequirement
      DECODE(t.requirement, NULL, trr.listvalue, t.requirement)
    ELSE
      --if tr.resulttype is blank, specification_range=blank, ELSE=tr.requiremnt
      DECODE(tr.resulttype,NULL,NULL,tr.requirement) END
  AS specification_range, --[SPECIFICATION_RANGE]

  CASE WHEN tr.resulttype = 'NUMERIC' AND tr.status = 70
    THEN
      DECODE(
        tr.numericalresult,
        -- IF tr.numericalresult=O THEN "Absent/<unit>"
        0,'Absent'
          ||DECODE(tr.unit,NULL,NULL,'/'||tr.unit),   -- if tr.unit=blank THEN blank ELSE /tr.unit
        -- else RETURN prefix & number result &
        tr.prefix
          --remove (<≤>≥) prefixes and format numbes with commas
          ||TRIM(TO_CHAR(REGEXP_SUBSTR(REPLACE(tr.numericalresulttext,tr.prefix,''),'^\d+'),'999,999,999'))
          --if there is more than 1 '.' in the result
          ||CASE WHEN INSTR(tr.numericalresulttext,'.') > 0
            THEN --??
              SUBSTR(tr.numericalresulttext,INSTR(tr.numericalresulttext,'.')) END
          -- add ' 'units if not NULL
          ||DECODE(tr.unit,NULL,NULL,' '||tr.unit)
      )
    WHEN tr.resulttype IN ('LIST','TEXT') AND tr.status = 70
      THEN
        tr.textresult||DECODE(tr.unit,NULL,NULL,' '||tr.unit)
    WHEN tr.status = 10
      THEN
        'pending'
      ELSE
        'Not Tested' END
  AS result,                  --{RESULT}


  TO_CHAR(TO_DATE(SUBSTR(tr.resultdate,1,8),'YYYYMMDD'),'DD-MON-YYYY')
        AS test_date,          --{TEST_DATE}
  sm.description AS method,     --{METHOD}
  tr.generic01 AS notebook_ref, --{NOTEBOOK_REF}

  (SELECT dv.description
    FROM domainvalue dv         --[dv] domainvalue
    WHERE UPPER(dv.domainid) = 'REPORT PARAMETERS' AND UPPER(dv.value) = 'DATE FORMAT' AND dv.deletion = 'N'
  ) AS report_date_format       --{REPORT_DATE_FORMAT}
FROM (
  SELECT DISTINCT ps.sampleguid, ps.batchnumber, ps.generic01, ps.generic04, ps.formulationid
  FROM physicalsample ps --[ps]
  JOIN testresult tr ON tr.sampleguid = ps.sampleguid
    AND tr.deletion = 'N'
  JOIN test t ON t.testguid = tr.testguid
    AND UPPER(t.testgroup) = 'MICRO'
    AND t.deletion = 'N'
  WHERE ps.batchnumber IS NOT NULL
    AND ps.deletion = 'N'
) psi --[psi]
JOIN testresult tr ON tr.sampleguid = psi.sampleguid
  AND tr.deletion = 'N'
JOIN test t ON t.testguid = tr.testguid
  AND UPPER(t.testgroup) = 'MICRO'
  AND t.deletion = 'N'

LEFT JOIN testresultrequirement trr ON trr.resultguid = tr.resultguid
  AND trr.valuationcode = 1


LEFT JOIN smmethod sm ON sm.methodid = t.methodid
  AND sm.versionno = t.methodversionno
  AND sm.deletion = 'N'
LEFT JOIN physicalsample ps ON ps.sampleguid = psi.sampleguid
LEFT JOIN specificationtestresult str ON str.specificationid = ps.specificationid
  AND str.versionno = ps.specificationversionno
  AND str.testid = t.testid
  AND str.resultid = tr.resultid
  AND str.deletion = 'N'
LEFT JOIN specificationtest st ON st.specificationid = str.specificationid
  AND st.versionno = str.versionno
  AND st.testguid = str.testguid
WHERE psi.batchnumber = $P{MICBATCHNUMBER}
  AND (($P{MICPKGLOT} IS NOT NULL
  AND psi.generic01 = $P{MICPKGLOT})
  OR $P{MICPKGLOT} IS NULL)
  AND (($P{MICBLISTERLOT} IS NOT NULL
  AND psi.generic04 = $P{MICBLISTERLOT})
  OR $P{MICBLISTERLOT} IS NULL)
  AND (st.deletion IS NULL
  OR (st.deletion IS NOT NULL
  AND st.deletion = 'N'))
ORDER BY DECODE(st.seqno,NULL,t.seqno,NULL), DECODE(str.seqno,NULL,tr.sequencenumber,str.seqno)
