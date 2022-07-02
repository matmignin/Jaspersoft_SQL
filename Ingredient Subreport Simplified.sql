SELECT
    -- Ingredient info
    i.generic2 AS ingredient_group,
    i.ingredientid,
    i.generic1 AS label_claim,
   	-- Ingredient Test Result info
    ir.specification_range,
    ir.resultdate AS test_date,
    ir.method,
    ir.generic01 AS notebook_ref,
   	ir.status,


    -- Ingredient name/description
    -- Handling The Generic Ingredients A-Q + mulitpart list
    CASE -- if i.IngredientId contain Generic Ingredient ___ then combine it with the discription from the other i.IngredientIds that also contain Generic ingredient**
        WHEN UPPER(i.ingredientid) LIKE 'MULTI-PART INGREDIENT LIST%'
        THEN -- then combine it with other rows that contain "MULTI...""
            (
             SELECT LISTAGG(i2.description) --aggrigates a multiple rows together into one and orders it
             WITHIN GROUP (ORDER BY i2.ingredientid) -- then orders
             FROM ingredient i2 -- referenceing the ingredientid twice
             WHERE UPPER(i2.ingredientid) LIKE 'MULTI%' -- if ingredientid starts with "Multi"
             AND i2.formulationguid = i.formulationguid -- and if the rows have matching formulationguid
             )
        WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT A%'
        THEN
            (SELECT LISTAGG(i2.description) WITHIN GROUP (ORDER BY i2.ingredientid)
             FROM ingredient i2
             WHERE UPPER(ingredientid) LIKE 'GENERIC INGREDIENT A%' AND i2.formulationguid = i.formulationguid)
        WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT Q%'
        THEN
            (SELECT LISTAGG(i2.description) WITHIN GROUP (ORDER BY i2.ingredientid)
             FROM ingredient i2
             WHERE UPPER(ingredientid) LIKE 'GENERIC INGREDIENT Q%' AND i2.formulationguid = i.formulationguid)
        ELSE i.description --if the ingredient.Description doesn't have Generic ingredient, the just return the discription
    END AS ingredient, --call the output of this "loop" Ingredient


    -- Result display value
    CASE
        -- format any results that numeric, relased, not skiploted or blank
        WHEN ir.resulttype = 'NUMERIC' AND ir.status = 70 AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        -- format the result to be "<Prefix>comma-separated digetsand add commas
        THEN ir.prefix||TRIM(TO_CHAR(REGEXP_SUBSTR(REPLACE(ir.numericalresulttext,ir.prefix,''),'^\d+'),'999,999,999'))
             || ( -- whenever the reesult contains a decemal but doesn't start with it
                 CASE WHEN INSTR(ir.numericalresulttext,'.') > 0
                 -- extract any digets after the decimal
                 THEN SUBSTR(ir.numericalresulttext,INSTR(ir.numericalresulttext,'.'))
                 END
                )
                -- if Unit is Blank, the return blank,
             || DECODE(ir.unit,NULL,NULL,
                    ' '||ir.unit) -- else return a space and unit
        WHEN ir.resulttype IN ('LIST','TEXT')
            AND ir.status = 70
            AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        THEN
            ir.textresult || DECODE(ir.unit,NULL,NULL,' ' || ir.unit)
        WHEN ir.status = 10
            AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        THEN
             'pending'
        ELSE
            CASE
                WHEN UPPER(i.ingredientid) LIKE 'INGREDIENT NOTE%'
                    OR UPPER(i.ingredientid) LIKE 'MULTI-PART INGREDIENT LIST%'
                    AND i.generic3 IS NULL
                THEN
                    ''
                WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT%'
                    AND i.generic3 IS NULL
                THEN
                    'Not Tested'
                WHEN i.generic3 IS NOT NULL
                THEN
                    i.generic3
                ELSE 'Not Tested'
            END
    END AS result --{RESULT}
FROM
    -- Ingredients for this product/formulation
    ingredient i --[i] ingredient
    JOIN formulation f ON i.formulationguid = f.formulationguid
            AND f.productid =  $P{PRODUCTID}
            AND f.formulationid  =  $P{FORMULATIONID}
            AND f.deletion = 'N'
    -- Join test results to the ingredients
    LEFT JOIN
    --__ creat a new table and call it ir
      (
        SELECT t.testid, t.testgroup,
                tr.resultid, tr.resultguid, tr.resulttype, tr.prefix, tr.numericalresulttext, tr.textresult, tr.unit,
                tr.requirement, tr.resultvaluation, tr.status, tr.resultdate,tr.generic01,
                trr.listvalue,
                -- Specification Range
                CASE
                    WHEN tr.resulttype = 'LIST'
                        AND (tr.resultvaluation <> 'SKIP LOT' OR tr.resultvaluation IS NULL)
                    THEN
                        DECODE(t.requirement, NULL, trr.listvalue, t.requirement)
                    WHEN tr.resulttype <> 'LIST'
                        AND (tr.resultvaluation <> 'SKIP LOT' OR tr.resultvaluation IS NULL)
                    THEN
                      DECODE(tr.resulttype,NULL,NULL,tr.requirement)
                    ELSE  ''
                 END AS specification_range, --{SPECIFICATION_RANGE}
                -- Method
                CASE
                    WHEN (tr.resultvaluation <> 'SKIP LOT'
                        OR tr.resultvaluation IS NULL)
                    THEN
                        sm.description
                    ELSE  ''
                END AS method --{METHOD}
                
        --__ All tests for the batch in one or more requests      
        FROM testresult tr --[tr] test result and [t] test
        JOIN test t 
          ON t.testguid = tr.testguid                   AND t.deletion = 'N'
            AND t.requestguid 
              IN (SELECT requestguid
                FROM testrequest
                WHERE batchnumber = $P{BATCHNUMBER}     AND deletion = 'N')
          
          -- join the sample method if matches
          LEFT JOIN smmethod sm 
            ON sm.methodid = t.methodid
              AND sm.versionno = t.methodversionno      AND sm.deletion = 'N'
              
          -- [trr] join testresultRequirement with test result
          LEFT JOIN testresultrequirement trr 
            ON trr.resultguid = tr.resultguid
              AND trr.valuationcode = 1
            WHERE tr.deletion = 'N'
              AND tr.flagisfinalresult = 'Y'
              AND configurationid <> 'Stability' --__(1.3.3) Fix Stability from showing up on the CoA
      ) ir ON UPPER(i.ingredientid) = UPPER(ir.resultid)
        --// ir.specification_range
        --// test_date
        --// ir.method,  
        --// notebook_ref
        --// ir.status


WHERE i.deletion = 'N'
  AND NOT(UPPER(i.ingredientid) LIKE 'MULTI%'
	AND SUBSTR(i.ingredientid,-1,1) <> 1)
	AND NOT(UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT%'
	AND SUBSTR(i.ingredientid,-1,1) <> 1)
	
ORDER BY i.position
