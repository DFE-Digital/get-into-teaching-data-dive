alter view git.profile as
    with countries_with_600_candidates as (
        select
            c.dfe_country
        from
            crm_contact c
        where
            c.createdon >= '2019-01-01'
        group by 
            c.dfe_country
        having
            count(*) >= 600
    )
    select
        -- contact id, the unique identifier for the candidate
        c.id,

        -- the candidate's commitment level - values are:
        -- * It's just an idea
        -- * I'm not sure and am finding out more
        -- * I'm fairly sure and am exploring my options
        -- * I'm very sure and think I'll apply
        ls.LocalizedLabel as journey_stage,

        -- the contact's degree status - values are:
        -- 'Graduate or postgraduate', 'Final year', 'Second year',
        -- 'I don't have a degree' and 'Other'
        ds.LocalizedLabel as degree_status,

        -- the names of the two subjects chosen when signing up
        -- to various services.
        -- * subject 1 is required
        -- * in School Experience - subject 2 is optional
        -- * in Get Into Teaching - subject 2 is not asked for
        tsl1.dfe_name as preferred_teaching_subject_1,
        tsl2.dfe_name as preferred_teaching_subject_2,

        -- do we have a postcode for this candidate?
        --
        -- there appears to be some invalid data in this column so
        -- we're using length as a proxy for validity, valid postcodes
        -- range from 5 characters (with no space, A9 9AA) to 8
        -- characters (with a space, AA99 9AA)
        case
            when len(c.address1_postalcode) between 5 and 8 then 1
            else 0
        end as has_postcode,

        -- do we have a date of birth for this candidate?
        case
            when c.birthdate is null then 0
            else 1
        end as has_date_of_birth,

        -- the date and time an adviser was assigned
        convert(smalldatetime, c.dfe_dateassignedtoadvisor) as adviser_assigned_at,

        -- the date on which an adviser was assigned
        convert(date, c.dfe_dateassignedtoadvisor) as adviser_assigned_on,

		-- has an adviser been assigned?
		case
			when c.dfe_dateassignedtoadvisor is null then 0
			else 1
		end as has_adviser,

        -- is the candidate from somewhere other than the UK?
        case
            -- assume domestic when nothing specified
            when c.dfe_country is null
                then 0
            when country.dfe_name = 'United Kingdom'
                then 0
            else 
                1
        end as international,

        -- is the candidate fresh or are they returning to teaching?
        case
            when toc.[LocalizedLabel] = 'RTT'
                then 1
            else
                0
        end as returner,

        -- most frequent candidate countries, don't return any
        -- with just a few candidates so we can't identify anyone
        case
            when c.dfe_country is null
                then 'Unknown'
            when c.dfe_country in (select * from countries_with_600_candidates)
                then country.dfe_name
        else
            'Other'
        end as country
    from
        crm_contact c

    left outer join
        -- list of candidate qualifications
        crm_dfe_candidatequalification cq
            on c.id = cq.dfe_contactid

    left outer join
        -- dynamics global EAV lookup
        crm_GlobalOptionSetMetaData ds
            on cq.dfe_degreestatus = ds.[Option]
            and ds.[OptionSetName] = 'dfe_degreestatus'

    left outer join
        -- dynamics central EAV lookup
        crm_OptionSetMetadata ls
            on c.dfe_lifestage = ls.[Option]
            and ls.OptionSetName = 'dfe_lifestage'

    left outer join
        crm_dfe_teachingsubjectlist tsl1
            on c.dfe_preferredteachingsubject01 = tsl1.id

    left outer join
        crm_dfe_teachingsubjectlist tsl2
            on c.dfe_preferredteachingsubject02 = tsl2.id

    left outer join
        crm_dfe_country country
            on c.dfe_country = country.id

    left outer join
        crm_GlobalOptionSetMetaData toc
            on c.dfe_typeofcandidate = toc.[Option]
            and toc.OptionSetName = 'dfe_typeofcandidate'        

    where
        c.createdon >= '2019-01-01'
;