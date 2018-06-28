SELECT
	studentID
	,FIRST_NAME 'firstName'
	,LAST_NAME 'lastName'
	,currentUserName
	,password
	,PERSON_EMAIL_ADDRESSES 'email'
	,address
	,[Emergency Contact Name] 'emergencyContactName'
	,REPLACE(
		REPLACE(
			REPLACE(
				REPLACE(
					[Emergency Contact Phone], '-', ''
					), ' ', ''
				), '(', ''
			), ')', ''
	) AS 'emergencyContactPhone'
	,CITY
	,STATE
	,ZIP
	,COUNTRY
	,CASE WHEN STU_TYPES IN ('IE', 'EXCH') THEN 'International' END AS 'internationalFlag'
	,NULL AS 'bestDepartment'
	,altCountry
	,altState
	,altCity
	,altZip
	,altAddress

	,fullQuery.ADDRESS_CHANGE_DATE
	,fullQuery.ADDRESS_CHANGE_DATE2
	,fullQuery.PERSON_CHANGE_DATE
	,[adClass]
FROM

(
	SELECT 
		PERSON.ID AS 'studentID'
		,CASE WHEN FIRST_NAME='''' THEN NULL ELSE REPLACE(FIRST_NAME, ' ', '') END AS FIRST_NAME
		,LAST_NAME
		,REPLACE(REPLACE(REPLACE(PERSON.FIRST_NAME, '''' , ''), '-','') + REPLACE(REPLACE(REPLACE(LAST_NAME, '''', ''), ' ', ''),'-',''), ' ', '') AS 'currentUserName'
		,CONCAT('Im@',Substring(CONVERT(varchar(4),DATEPART(year, PERSON.BIRTH_DATE)),3,2)+
			CONVERT(varchar(2), PERSON.BIRTH_DATE, 101) +
			CONVERT(varchar(2), PERSON.BIRTH_DATE, 103)) AS 'password'
		,PERSON_EMAIL_ADDRESSES	
		,LOWER(
			SUBSTRING(FIRST_NAME, 1, 1)
			+ SUBSTRING(LAST_NAME, 1, 4)
			+ RIGHT(PERSON.ID, 3)
		) AS 'newUsername'

		,STU_TYPES

		,NULL AS 'SEC_DEPTS'

		,CONCAT(
			ISNULL(address1.ADDRESS_LINES, ''), 
			CASE WHEN address2.ADDRESS_LINES IS NULL THEN '' ELSE ' ' END, 
			ISNULL(address2.ADDRESS_LINES, '') 
		) 'address'

		,ADDRESS.CITY
		,ADDRESS.STATE

		,CASE WHEN 
			(
			ADDRESS.ZIP LIKE '%1%'
			OR ADDRESS.ZIP LIKE '%2%'
			OR ADDRESS.ZIP LIKE '%3%'
			OR ADDRESS.ZIP LIKE '%4%'
			OR ADDRESS.ZIP LIKE '%5%'
			OR ADDRESS.ZIP LIKE '%6%'
			OR ADDRESS.ZIP LIKE '%7%'
			OR ADDRESS.ZIP LIKE '%8%'
			OR ADDRESS.ZIP LIKE '%9%'
			OR ADDRESS.ZIP LIKE '%0%'
		) THEN ADDRESS.ZIP ELSE NULL END AS 'ZIP'

		,CASE WHEN ADDRESS.COUNTRY='CA' THEN NULL ELSE CTRY_DESC END AS 'COUNTRY'
		,ADDRESS.COUNTRY AS 'prefCountry'

		,EMER_NAME 'Emergency Contact Name'
		,CASE WHEN EMER_DAYTIME_PHONE IS NULL THEN EMER_EVENING_PHONE ELSE EMER_DAYTIME_PHONE END AS 'Emergency Contact Phone'

		,NULL AS 'sectionCount'
	
		,alternativeAddress.COUNTRY AS 'altCountry'
		,alternativeAddress.CITY as 'altCity'
		,alternativeAddress.ZIP AS 'altZip'
		,alternativeAddress.STATE AS 'altState'
		,CONCAT(
			ISNULL(altAddress1.ADDRESS_LINES, ''),
			CASE WHEN altAddress2.ADDRESS_LINES IS NULL THEN '' ELSE ' ' END,
			ISNULL(altAddress2.ADDRESS_LINES, '')
		) AS 'altAddress'

		,PERSON.PERSON_CHANGE_DATE
		,ADDRESS.ADDRESS_CHANGE_DATE
		,ADDRESS.ADDRESS_CHANGE_DATE2
		,NULL AS 'STUDENT_ACAD_CRED_ADDDATE'
		,ROW_NUMBER() OVER (PARTITION BY [SCS_STUDENT] ORDER BY [helper] ASC) AS 'rn'
		,[adClass]
	FROM
		(
		--this query provides active student subset
		SELECT DISTINCT
			SCS_STUDENT
			,'activeStudent' 'adClass'
			,'1' 'helper'
		FROM	
			COURSE_SECTIONS
		LEFT JOIN
			STUDENT_COURSE_SEC ON 
			COURSE_SECTIONS.COURSE_SECTIONS_ID=SCS_COURSE_SECTION
		LEFT JOIN
			SEC_STATUSES ON 
			COURSE_SECTIONS.COURSE_SECTIONS_ID=SEC_STATUSES.COURSE_SECTIONS_ID AND SEC_STATUSES.POS=1
		LEFT JOIN
			STC_STATUSES ON
			STUDENT_COURSE_SEC.SCS_STUDENT_ACAD_CRED=STC_STATUSES.STUDENT_ACAD_CRED_ID AND STC_STATUSES.POS=1
		LEFT JOIN
			SEC_DEPARTMENTS ON 
			COURSE_SECTIONS.COURSE_SECTIONS_ID=SEC_DEPARTMENTS.COURSE_SECTIONS_ID AND SEC_DEPT_PCTS=100
		LEFT JOIN	
			TERMS ON
			SEC_TERM=TERMS.TERMS_ID
		LEFT JOIN
			STUDENT_ACAD_CRED ON
			SCS_STUDENT_ACAD_CRED=STUDENT_ACAD_CRED.STUDENT_ACAD_CRED_ID
		WHERE
			SEC_STATUS='A'
			AND STC_STATUS IN ('N', 'A')
			AND DATEDIFF(dd, TERM_START_DATE, GETDATE()) <= 240
			AND GETDATE() <= STC_END_DATE

		UNION

		--this query provides prospective student subset. Active supersedes
		SELECT DISTINCT
			APPL_APPLICANT
			,'prospectiveStudent'
			,'2'
		FROM
			APPLICATIONS
		LEFT JOIN
			APPL_STATUSES ON
			APPLICATIONS.APPLICATIONS_ID=APPL_STATUSES.APPLICATIONS_ID AND APPL_STATUSES.POS=1
		LEFT JOIN
			TERMS ON
			APPL_START_TERM=TERMS_ID
		WHERE
			APPL_STATUS IN ('AC', 'RG', 'CQ')
			AND TERM_START_DATE + 30 > GETDATE()


		--this query provides dorm-only subset. Active and prospective supersede, and employees subset is removed.
		UNION

		SELECT DISTINCT
			RMAS_PERSON_ID
			,'dormOnly'
			,'3'
		FROM
			ROOM_ASSIGNMENT
		LEFT JOIN
			RMAS_STATUSES ON 
			ROOM_ASSIGNMENT.ROOM_ASSIGNMENT_ID=RMAS_STATUSES.ROOM_ASSIGNMENT_ID AND RMAS_STATUSES.POS=1
		WHERE
			RMAS_STATUS NOT IN ('C', 'E', 'T')
			AND RMAS_END_DATE+1 >= GETDATE()
			AND NOT RMAS_PERSON_ID IN (SELECT HRPER_ID FROM HRPER)
	) adClassQuery 
	--extra info for data cleaning/address processing
	LEFT JOIN PERSON ON SCS_STUDENT=PERSON.ID
	LEFT JOIN PEOPLE_EMAIL ON PERSON.ID=PEOPLE_EMAIL.ID AND PERSON_PREFERRED_EMAIL='Y'
	LEFT JOIN
		EMER_CONTACTS ON
		PERSON.ID=EMER_CONTACTS.PERSON_EMER_ID AND EMER_CONTACTS.POS=1
		AND NOT EMER_DAYTIME_PHONE LIKE '%[a-z]%'
	LEFT JOIN
		STU_TYPE_INFO ON
		PERSON.ID=STU_TYPE_INFO.STUDENTS_ID AND STU_TYPE_INFO.POS=1 AND (STU_TYPES='IE' OR STU_TYPES='EXCH')
	LEFT JOIN
		PSEASON ON
		PERSON.ID=PSEASON.ID
	LEFT JOIN
		ADDRESS ON
		PERSON.PREFERRED_ADDRESS=ADDRESS.ADDRESS_ID
	LEFT JOIN
		ADDRESS_LS address1 ON
		PERSON.PREFERRED_ADDRESS=address1.ADDRESS_ID AND address1.POS=1
	LEFT JOIN
		ADDRESS_LS address2 ON
		PERSON.PREFERRED_ADDRESS=address2.ADDRESS_ID and address2.POS=2
	LEFT JOIN
		ADDRESS alternativeAddress ON
		PSEASON.PERSON_ADDRESSES=alternativeAddress.ADDRESS_ID 
		AND PSEASON.POS=2 
		AND NOT PSEASON.PERSON_ADDRESSES=PERSON.PREFERRED_ADDRESS
		AND 
			(
			NOT ADDRESS.COUNTRY=alternativeAddress.COUNTRY
			OR (
				ADDRESS.COUNTRY IS NOT NULL 
				AND alternativeAddress.COUNTRY IS NULL 
				AND NOT ADDRESS.COUNTRY='CA'
				)
			)
	LEFT JOIN
		ADDRESS_LS altAddress1 ON
		alternativeAddress.ADDRESS_ID=altAddress1.ADDRESS_ID AND altAddress1.POS=1
	LEFT JOIN
		ADDRESS_LS altAddress2 ON
		alternativeAddress.ADDRESS_ID=altAddress2.ADDRESS_ID AND altAddress2.POS=2
	LEFT JOIN
		COUNTRIES ON 
		ADDRESS.COUNTRY=COUNTRIES.COUNTRIES_ID

) fullQuery
WHERE
	rn=1