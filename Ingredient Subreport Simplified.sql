SELECT
    -- Ingredient info
    i.generic2 AS ingredient_group,  -- JASPERSOFT parameter
    i.ingredientid,
    i.generic1 AS label_claim,  -- JASPERSOFT parameter
    -- Ingredient Test Result info
    ir.specification_range,
    ir.resultdate AS test_date,  -- JASPERSOFT parameter
    ir.method,
    ir.generic01 AS notebook_ref,  -- JASPERSOFT parameter
    ir.status,
    trq.generic03 AS annual_sample, ---[testing] Annual update (pending)

    -- Ingredient name/descriptiona
    CASE
        -- Handling The Generic Ingredients A-Q + mulitpart list
        WHEN UPPER(i.ingredientid) LIKE 'MULTI-PART INGREDIENT LIST%'
        -- if i.IngredientId contain Generic Ing*_ then combine it with the discrip from the other i.Ingredie that also contains the same Generic ing
        THEN ( --  combine it with the other rows that contain "MULTI..." and match ingredient ID
                SELECT LISTAGG(i2.description) --aggrigates a multiple rows together into one and orders it
                WITHIN GROUP (ORDER BY i2.ingredientid) -- then orders
                FROM ingredient i2 -- referenceing the ingredientid twice
                WHERE UPPER(i2.ingredientid) LIKE 'MULTI%' -- if ingredientid starts with "Multi"
                AND i2.formulationguid = i.formulationguid -- and if the rows have matching formulationguid
                )
        WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT A%'
        THEN (
                SELECT LISTAGG(i2.description) WITHIN GROUP (ORDER BY i2.ingredientid)
                FROM ingredient i2
                WHERE UPPER(ingredientid) LIKE 'GENERIC INGREDIENT A%' AND i2.formulationguid = i.formulationguid
                )
        WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT Q%'
        THEN (
                SELECT LISTAGG(i2.description) WITHIN GROUP (ORDER BY i2.ingredientid)
                FROM ingredient i2
                WHERE UPPER(ingredientid) LIKE 'GENERIC INGREDIENT Q%' AND i2.formulationguid = i.formulationguid
                )
        ELSE i.description --if the i.ingredient.Description doesn't have Generic ingredient, the just return the discription
    END AS ingredient, -- JASPERSOFT parameter

    -- Format Result display values
    CASE
        WHEN ir.resulttype = 'NUMERIC' AND ir.status = 70 AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        -- format the NUMERIC results that are relased, not skiploted or blank
            THEN -- format and Concat the results
                ir.prefix -- start with prefix
                || --will trim the numbers between the prefix and the first decimal
                    TRIM(TO_CHAR(REGEXP_SUBSTR(REPLACE(ir.numericalresulttext,ir.prefix,''),'^\d+'),'999,999,999'))
                || ( -- get the first chunk of digets before the period
                    CASE
                        WHEN INSTR(ir.numericalresulttext,'.') > 0 -- when the results have a "."
                            THEN -- extract any digets after the decimal
                                SUBSTR(ir.numericalresulttext,INSTR(ir.numericalresulttext,'.'))
                            END
                    )
                || -- add the units with a space or add nothing if NULL
                    DECODE(ir.unit,NULL,NULL,' '||ir.unit)
        WHEN ir.resulttype IN ('LIST','TEXT') AND ir.status = 70 AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        -- format any LIST or TEXT results
            THEN -- add the result and unit text
                ir.textresult || DECODE(ir.unit,NULL,NULL,' ' || ir.unit)
        WHEN ir.status = 10 AND (ir.resultvaluation <> 'SKIP LOT' OR ir.resultvaluation IS NULL)
        -- add Pending if status is Pending (10)
            THEN 'pending'
        ELSE
        -- Format what results for ingredients that dont get tested
            CASE
                WHEN UPPER(i.ingredientid) LIKE 'INGREDIENT NOTE%' OR UPPER(i.ingredientid) LIKE 'MULTI-PART INGREDIENT LIST%' AND i.generic3 IS NULL
                THEN '' -- show blank when Ingredient Note or Multi-Part
                WHEN UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT%' AND i.generic3 IS NULL
                    THEN 'Not Tested' -- show NOT tested when Generic Ingredient
                WHEN i.generic3 IS NOT NULL
                    THEN i.generic3 -- when the Results field on the composition is filled in
                ELSE 'Not Tested'
            END
    END AS result  -- JASPERSOFT parameter

-- Ingredients for this product/formulation (ir)
FROM ingredient i   --T (i) ingrident
    JOIN formulation f --T (f) formulation
    -- joins the matching FormulationGUID On Ingredients and Formulation
        ON i.formulationguid = f.formulationguid
        -- and if the formulations given through LMS parameter matches the Productid and Formulationid from the query
        AND f.productid =  $P{PRODUCTID} AND f.formulationid  =  $P{FORMULATIONID} AND f.deletion = 'N'
-- will Join test results to the ingredients (ir)
    LEFT JOIN ( -- will joins the Test(t) and TestResult(tr) and TestResultRequirement(trr)
        SELECT
        t.testid, t.testgroup,
        tr.resultid, tr.resultguid, tr.resulttype, tr.prefix, tr.numericalresulttext, tr.textresult, tr.unit, tr.requirement, tr.resultvaluation, tr.status, tr.resultdate,tr.generic01,
        trr.listvalue,
        -- Specification Range
        CASE
            WHEN tr.resulttype = 'LIST' AND (tr.resultvaluation <> 'SKIP LOT' OR tr.resultvaluation IS NULL)
            THEN DECODE(t.requirement, NULL, trr.listvalue, t.requirement)
            WHEN tr.resulttype <> 'LIST' AND (tr.resultvaluation <> 'SKIP LOT' OR tr.resultvaluation IS NULL)
            THEN DECODE(tr.resulttype,NULL,NULL,tr.requirement)
            ELSE  ''
        END AS specification_range,  --P (SPECIFICATION_RANGE)
        -- Method
        CASE
            WHEN (tr.resultvaluation <> 'SKIP LOT' OR tr.resultvaluation IS NULL)
            THEN sm.description
            ELSE  ''
        END AS method --P (METHOD)

        FROM testresult tr  --T (tr) testresult
            JOIN test t     --T (t) test
            ON t.testguid = tr.testguid AND t.deletion = 'N' AND t.requestguid
                IN ( -- All tests for the batch in one or more requests
                    SELECT requestguid
                    FROM testrequest trq
                    WHERE  batchnumber =  $P{BATCHNUMBER} AND deletion = 'N'
                )
        LEFT JOIN smmethod sm  --T (sm) smmethod
            ON sm.methodid = t.methodid AND sm.versionno = t.methodversionno AND sm.deletion = 'N'
        LEFT JOIN testresultrequirement trr --T (trr) testresultrequirement
            ON trr.resultguid = tr.resultguid AND trr.valuationcode = 1
            WHERE tr.deletion = 'N' AND tr.flagisfinalresult = 'Y' AND configurationid <> 'Stability'
    ) ir            --__Joining of results to ingredients (ir) Used at top
    ON UPPER(i.ingredientid) = UPPER(ir.resultid)
    WHERE i.deletion = 'N'
    AND NOT(UPPER(i.ingredientid) LIKE 'MULTI%'
        AND SUBSTR(i.ingredientid,-1,1) <> 1) -- ??
        AND NOT(UPPER(i.ingredientid) LIKE 'GENERIC INGREDIENT%'
        AND SUBSTR(i.ingredientid,-1,1) <> 1)
ORDER BY i.position
