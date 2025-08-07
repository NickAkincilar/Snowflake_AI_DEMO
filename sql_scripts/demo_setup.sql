


    -- ========================================================================
    -- Snowflake AI Demo - Complete Setup Script
    -- This script creates the database, schema, tables, and loads all data
    -- Repository: https://github.com/NickAkincilar/Snowflake_AI_DEMO.git
    -- ========================================================================

    

    -- Switch to accountadmin role to create warehouse
    USE ROLE accountadmin;


    -- CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
    -- CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;
    -- -- Allow anyone to see the agents in this schema
    GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
    GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;


    create or replace role SF_Intelligence_Demo;


    SET current_user_name = CURRENT_USER();
    
    -- Step 2: Use the variable to grant the role
    GRANT ROLE SF_Intelligence_Demo TO USER IDENTIFIER($current_user_name);
    GRANT CREATE DATABASE ON ACCOUNT TO ROLE SF_Intelligence_Demo;
    
    -- Create a dedicated warehouse for the demo with auto-suspend/resume
    CREATE OR REPLACE WAREHOUSE Snow_Intelligence_demo_wh 
        WITH WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 300
        AUTO_RESUME = TRUE;


    -- Grant usage on warehouse to admin role
    GRANT USAGE ON WAREHOUSE SNOW_INTELLIGENCE_DEMO_WH TO ROLE SF_Intelligence_Demo;


   -- Alter current user's default role and warehouse to the ones used here
    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SF_Intelligence_Demo;
    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = Snow_Intelligence_demo_wh;
    

    -- Switch to SF_Intelligence_Demo role to create demo objects
    use role SF_Intelligence_Demo;
   
    -- Create database and schema
    CREATE OR REPLACE DATABASE SF_AI_DEMO;
    USE DATABASE SF_AI_DEMO;

    CREATE SCHEMA IF NOT EXISTS DEMO_SCHEMA;
    USE SCHEMA DEMO_SCHEMA;

    -- Create file format for CSV files
    CREATE OR REPLACE FILE FORMAT CSV_FORMAT
        TYPE = 'CSV'
        FIELD_DELIMITER = ','
        RECORD_DELIMITER = '\n'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        TRIM_SPACE = TRUE
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        ESCAPE = 'NONE'
        ESCAPE_UNENCLOSED_FIELD = '\134'
        DATE_FORMAT = 'YYYY-MM-DD'
        TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
        NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');


use role accountadmin;
    -- Create API Integration for GitHub (public repository access)
    CREATE OR REPLACE API INTEGRATION git_api_integration
        API_PROVIDER = git_https_api
        API_ALLOWED_PREFIXES = ('https://github.com/NickAkincilar/')
        ENABLED = TRUE;


GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SF_Intelligence_Demo;


use role SF_Intelligence_Demo;
    -- Create Git repository integration for the public demo repository
    CREATE OR REPLACE GIT REPOSITORY SF_AI_DEMO_REPO
        API_INTEGRATION = git_api_integration
        ORIGIN = 'https://github.com/NickAkincilar/Snowflake_AI_DEMO.git';

    -- Create internal stage for copied data files
    CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
        FILE_FORMAT = CSV_FORMAT
        COMMENT = 'Internal stage for copied demo data files'
        DIRECTORY = ( ENABLE = TRUE)
        ENCRYPTION = (   TYPE = 'SNOWFLAKE_SSE');

    ALTER GIT REPOSITORY SF_AI_DEMO_REPO FETCH;

    -- ========================================================================
    -- COPY DATA FROM GIT TO INTERNAL STAGE
    -- ========================================================================

    -- Copy all CSV files from Git repository demo_data folder to internal stage
    COPY FILES
    INTO @INTERNAL_DATA_STAGE/demo_data/
    FROM @SF_AI_DEMO_REPO/branches/main/demo_data/;


    COPY FILES
    INTO @INTERNAL_DATA_STAGE/unstructured_docs/
    FROM @SF_AI_DEMO_REPO/branches/main/unstructured_docs/;

    -- Verify files were copied
    LS @INTERNAL_DATA_STAGE;

    ALTER STAGE INTERNAL_DATA_STAGE refresh;

  

    -- ========================================================================
    -- DIMENSION TABLES
    -- ========================================================================

    -- Product Category Dimension
    CREATE OR REPLACE TABLE product_category_dim (
        category_key INT PRIMARY KEY,
        category_name VARCHAR(100) NOT NULL,
        vertical VARCHAR(50) NOT NULL
    );

    -- Product Dimension
    CREATE OR REPLACE TABLE product_dim (
        product_key INT PRIMARY KEY,
        product_name VARCHAR(200) NOT NULL,
        category_key INT NOT NULL,
        category_name VARCHAR(100),
        vertical VARCHAR(50)
    );

    -- Vendor Dimension
    CREATE OR REPLACE TABLE vendor_dim (
        vendor_key INT PRIMARY KEY,
        vendor_name VARCHAR(200) NOT NULL,
        vertical VARCHAR(50) NOT NULL,
        address VARCHAR(200),
        city VARCHAR(100),
        state VARCHAR(10),
        zip VARCHAR(20)
    );

    -- Customer Dimension
    CREATE OR REPLACE TABLE customer_dim (
        customer_key INT PRIMARY KEY,
        customer_name VARCHAR(200) NOT NULL,
        industry VARCHAR(100),
        vertical VARCHAR(50),
        address VARCHAR(200),
        city VARCHAR(100),
        state VARCHAR(10),
        zip VARCHAR(20)
    );

    -- Account Dimension (Finance)
    CREATE OR REPLACE TABLE account_dim (
        account_key INT PRIMARY KEY,
        account_name VARCHAR(100) NOT NULL,
        account_type VARCHAR(50)
    );

    -- Department Dimension
    CREATE OR REPLACE TABLE department_dim (
        department_key INT PRIMARY KEY,
        department_name VARCHAR(100) NOT NULL
    );

    -- Region Dimension
    CREATE OR REPLACE TABLE region_dim (
        region_key INT PRIMARY KEY,
        region_name VARCHAR(100) NOT NULL
    );

    -- Sales Rep Dimension
    CREATE OR REPLACE TABLE sales_rep_dim (
        sales_rep_key INT PRIMARY KEY,
        rep_name VARCHAR(200) NOT NULL,
        hire_date DATE
    );

    -- Campaign Dimension (Marketing)
    CREATE OR REPLACE TABLE campaign_dim (
        campaign_key INT PRIMARY KEY,
        campaign_name VARCHAR(300) NOT NULL,
        objective VARCHAR(100)
    );

    -- Channel Dimension (Marketing)
    CREATE OR REPLACE TABLE channel_dim (
        channel_key INT PRIMARY KEY,
        channel_name VARCHAR(100) NOT NULL
    );

    -- Employee Dimension (HR)
    CREATE OR REPLACE TABLE employee_dim (
        employee_key INT PRIMARY KEY,
        employee_name VARCHAR(200) NOT NULL,
        gender VARCHAR(1),
        hire_date DATE
    );

    -- Job Dimension (HR)
    CREATE OR REPLACE TABLE job_dim (
        job_key INT PRIMARY KEY,
        job_title VARCHAR(100) NOT NULL,
        job_level INT
    );

    -- Location Dimension (HR)
    CREATE OR REPLACE TABLE location_dim (
        location_key INT PRIMARY KEY,
        location_name VARCHAR(200) NOT NULL
    );

    -- ========================================================================
    -- FACT TABLES
    -- ========================================================================

    -- Sales Fact Table
    CREATE OR REPLACE TABLE sales_fact (
        sale_id INT PRIMARY KEY,
        date DATE NOT NULL,
        customer_key INT NOT NULL,
        product_key INT NOT NULL,
        sales_rep_key INT NOT NULL,
        region_key INT NOT NULL,
        vendor_key INT NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        units INT NOT NULL
    );

    -- Finance Transactions Fact Table
    CREATE OR REPLACE TABLE finance_transactions (
        transaction_id INT PRIMARY KEY,
        date DATE NOT NULL,
        account_key INT NOT NULL,
        department_key INT NOT NULL,
        vendor_key INT NOT NULL,
        product_key INT NOT NULL,
        customer_key INT NOT NULL,
        amount DECIMAL(12,2) NOT NULL
    );

    -- Marketing Campaign Fact Table
    CREATE OR REPLACE TABLE marketing_campaign_fact (
        campaign_fact_id INT PRIMARY KEY,
        date DATE NOT NULL,
        campaign_key INT NOT NULL,
        product_key INT NOT NULL,
        channel_key INT NOT NULL,
        region_key INT NOT NULL,
        spend DECIMAL(10,2) NOT NULL,
        leads_generated INT NOT NULL,
        impressions INT NOT NULL
    );

    -- HR Employee Fact Table
    CREATE OR REPLACE TABLE hr_employee_fact (
        hr_fact_id INT PRIMARY KEY,
        date DATE NOT NULL,
        employee_key INT NOT NULL,
        department_key INT NOT NULL,
        job_key INT NOT NULL,
        location_key INT NOT NULL,
        salary DECIMAL(10,2) NOT NULL,
        attrition_flag INT NOT NULL
    );

    -- ========================================================================
    -- SALESFORCE CRM TABLES
    -- ========================================================================

    -- Salesforce Accounts Table
    CREATE OR REPLACE TABLE sf_accounts (
        account_id VARCHAR(20) PRIMARY KEY,
        account_name VARCHAR(200) NOT NULL,
        customer_key INT NOT NULL,
        industry VARCHAR(100),
        vertical VARCHAR(50),
        billing_street VARCHAR(200),
        billing_city VARCHAR(100),
        billing_state VARCHAR(10),
        billing_postal_code VARCHAR(20),
        account_type VARCHAR(50),
        annual_revenue DECIMAL(15,2),
        employees INT,
        created_date DATE
    );

    -- Salesforce Opportunities Table
    CREATE OR REPLACE TABLE sf_opportunities (
        opportunity_id VARCHAR(20) PRIMARY KEY,
        sale_id INT,
        account_id VARCHAR(20) NOT NULL,
        opportunity_name VARCHAR(200) NOT NULL,
        stage_name VARCHAR(100) NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        probability DECIMAL(5,2),
        close_date DATE,
        created_date DATE,
        lead_source VARCHAR(100),
        type VARCHAR(100)
    );

    -- Salesforce Contacts Table
    CREATE OR REPLACE TABLE sf_contacts (
        contact_id VARCHAR(20) PRIMARY KEY,
        opportunity_id VARCHAR(20) NOT NULL,
        account_id VARCHAR(20) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        email VARCHAR(200),
        phone VARCHAR(50),
        title VARCHAR(100),
        department VARCHAR(100),
        lead_source VARCHAR(100),
        campaign_no INT,
        created_date DATE
    );

    -- ========================================================================
    -- LOAD DIMENSION DATA FROM INTERNAL STAGE
    -- ========================================================================

    -- Load Product Category Dimension
    COPY INTO product_category_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/product_category_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Product Dimension
    COPY INTO product_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/product_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Vendor Dimension
    COPY INTO vendor_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/vendor_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Customer Dimension
    COPY INTO customer_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/customer_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Account Dimension
    COPY INTO account_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/account_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Department Dimension
    COPY INTO department_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/department_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Region Dimension
    COPY INTO region_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/region_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Sales Rep Dimension
    COPY INTO sales_rep_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/sales_rep_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Campaign Dimension
    COPY INTO campaign_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/campaign_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Channel Dimension
    COPY INTO channel_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/channel_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Employee Dimension
    COPY INTO employee_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/employee_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Job Dimension
    COPY INTO job_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/job_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Location Dimension
    COPY INTO location_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/location_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- ========================================================================
    -- LOAD FACT DATA FROM INTERNAL STAGE
    -- ========================================================================

    -- Load Sales Fact
    COPY INTO sales_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/sales_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Finance Transactions
    COPY INTO finance_transactions
    FROM @INTERNAL_DATA_STAGE/demo_data/finance_transactions.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Marketing Campaign Fact
    COPY INTO marketing_campaign_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/marketing_campaign_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load HR Employee Fact
    COPY INTO hr_employee_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/hr_employee_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- ========================================================================
    -- LOAD SALESFORCE DATA FROM INTERNAL STAGE
    -- ========================================================================

    -- Load Salesforce Accounts
    COPY INTO sf_accounts
    FROM @INTERNAL_DATA_STAGE/demo_data/sf_accounts.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Salesforce Opportunities
    COPY INTO sf_opportunities
    FROM @INTERNAL_DATA_STAGE/demo_data/sf_opportunities.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Salesforce Contacts
    COPY INTO sf_contacts
    FROM @INTERNAL_DATA_STAGE/demo_data/sf_contacts.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- ========================================================================
    -- VERIFICATION
    -- ========================================================================

    -- Verify Git integration and file copy
    SHOW GIT REPOSITORIES;
   -- SELECT 'Internal Stage Files' as stage_type, COUNT(*) as file_count FROM (LS @INTERNAL_DATA_STAGE);

    -- Verify data loads
    SELECT 'DIMENSION TABLES' as category, '' as table_name, NULL as row_count
    UNION ALL
    SELECT '', 'product_category_dim', COUNT(*) FROM product_category_dim
    UNION ALL
    SELECT '', 'product_dim', COUNT(*) FROM product_dim
    UNION ALL
    SELECT '', 'vendor_dim', COUNT(*) FROM vendor_dim
    UNION ALL
    SELECT '', 'customer_dim', COUNT(*) FROM customer_dim
    UNION ALL
    SELECT '', 'account_dim', COUNT(*) FROM account_dim
    UNION ALL
    SELECT '', 'department_dim', COUNT(*) FROM department_dim
    UNION ALL
    SELECT '', 'region_dim', COUNT(*) FROM region_dim
    UNION ALL
    SELECT '', 'sales_rep_dim', COUNT(*) FROM sales_rep_dim
    UNION ALL
    SELECT '', 'campaign_dim', COUNT(*) FROM campaign_dim
    UNION ALL
    SELECT '', 'channel_dim', COUNT(*) FROM channel_dim
    UNION ALL
    SELECT '', 'employee_dim', COUNT(*) FROM employee_dim
    UNION ALL
    SELECT '', 'job_dim', COUNT(*) FROM job_dim
    UNION ALL
    SELECT '', 'location_dim', COUNT(*) FROM location_dim
    UNION ALL
    SELECT '', '', NULL
    UNION ALL
    SELECT 'FACT TABLES', '', NULL
    UNION ALL
    SELECT '', 'sales_fact', COUNT(*) FROM sales_fact
    UNION ALL
    SELECT '', 'finance_transactions', COUNT(*) FROM finance_transactions
    UNION ALL
    SELECT '', 'marketing_campaign_fact', COUNT(*) FROM marketing_campaign_fact
    UNION ALL
    SELECT '', 'hr_employee_fact', COUNT(*) FROM hr_employee_fact
    UNION ALL
    SELECT '', '', NULL
    UNION ALL
    SELECT 'SALESFORCE TABLES', '', NULL
    UNION ALL
    SELECT '', 'sf_accounts', COUNT(*) FROM sf_accounts
    UNION ALL
    SELECT '', 'sf_opportunities', COUNT(*) FROM sf_opportunities
    UNION ALL
    SELECT '', 'sf_contacts', COUNT(*) FROM sf_contacts;

    -- Show all tables
    SHOW TABLES IN SCHEMA DEMO_SCHEMA; 




  -- ========================================================================
  -- Snowflake AI Demo - Semantic Views for Cortex Analyst
  -- Creates business unit-specific semantic views for natural language queries
  -- Based on: https://docs.snowflake.com/en/user-guide/views-semantic/sql
  -- ========================================================================
  USE ROLE SF_Intelligence_Demo;
  USE DATABASE SF_AI_DEMO;
  USE SCHEMA DEMO_SCHEMA;

  -- ========================================================================
  -- FINANCE SEMANTIC VIEW
  -- ========================================================================

 create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.FINANCE_SEMANTIC_VIEW
    tables (
        TRANSACTIONS as FINANCE_TRANSACTIONS primary key (TRANSACTION_ID) with synonyms=('finance transactions','financial data') comment='All financial transactions across departments',
        ACCOUNTS as ACCOUNT_DIM primary key (ACCOUNT_KEY) with synonyms=('chart of accounts','account types') comment='Account dimension for financial categorization',
        DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('business units','departments') comment='Department dimension for cost center analysis',
        VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for spend analysis',
        PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for transaction analysis',
        CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers') comment='Customer dimension for revenue analysis'
    )
    relationships (
        TRANSACTIONS_TO_ACCOUNTS as TRANSACTIONS(ACCOUNT_KEY) references ACCOUNTS(ACCOUNT_KEY),
        TRANSACTIONS_TO_DEPARTMENTS as TRANSACTIONS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
        TRANSACTIONS_TO_VENDORS as TRANSACTIONS(VENDOR_KEY) references VENDORS(VENDOR_KEY),
        TRANSACTIONS_TO_PRODUCTS as TRANSACTIONS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
        TRANSACTIONS_TO_CUSTOMERS as TRANSACTIONS(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY)
    )
    facts (
        TRANSACTIONS.TRANSACTION_AMOUNT as amount comment='Transaction amount in dollars',
        TRANSACTIONS.TRANSACTION_RECORD as 1 comment='Count of transactions'
    )
    dimensions (
        TRANSACTIONS.TRANSACTION_DATE as date with synonyms=('date','transaction date') comment='Date of the financial transaction',
        TRANSACTIONS.TRANSACTION_MONTH as MONTH(date) comment='Month of the transaction',
        TRANSACTIONS.TRANSACTION_YEAR as YEAR(date) comment='Year of the transaction',
        ACCOUNTS.ACCOUNT_NAME as account_name with synonyms=('account','account type') comment='Name of the account',
        ACCOUNTS.ACCOUNT_TYPE as account_type with synonyms=('type','category') comment='Type of account (Income/Expense)',
        DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','business unit') comment='Name of the department',
        VENDORS.VENDOR_NAME as vendor_name with synonyms=('vendor','supplier') comment='Name of the vendor',
        PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item') comment='Name of the product',
        CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','client') comment='Name of the customer'
    )
    metrics (
        TRANSACTIONS.AVERAGE_AMOUNT as AVG(transactions.amount) comment='Average transaction amount',
        TRANSACTIONS.TOTAL_AMOUNT as SUM(transactions.amount) comment='Total transaction amount',
        TRANSACTIONS.TOTAL_TRANSACTIONS as COUNT(transactions.transaction_record) comment='Total number of transactions'
    )
    comment='Semantic view for financial analysis and reporting';



  -- ========================================================================
  -- SALES SEMANTIC VIEW
  -- ========================================================================

create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.SALES_SEMANTIC_VIEW
	tables (
		CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers','accounts') comment='Customer information for sales analysis',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items','SKUs') comment='Product catalog for sales analysis',
		PRODUCT_CATEGORY_DIM primary key (CATEGORY_KEY),
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','areas') comment='Regional information for territory analysis',
		SALES as SALES_FACT primary key (SALE_ID) with synonyms=('sales transactions','sales data') comment='All sales transactions and deals',
		SALES_REPS as SALES_REP_DIM primary key (SALES_REP_KEY) with synonyms=('sales representatives','reps','salespeople') comment='Sales representative information',
		VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for supply chain analysis'
	)
	relationships (
		PRODUCT_TO_CATEGORY as PRODUCTS(CATEGORY_KEY) references PRODUCT_CATEGORY_DIM(CATEGORY_KEY),
		SALES_TO_CUSTOMERS as SALES(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY),
		SALES_TO_PRODUCTS as SALES(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		SALES_TO_REGIONS as SALES(REGION_KEY) references REGIONS(REGION_KEY),
		SALES_TO_REPS as SALES(SALES_REP_KEY) references SALES_REPS(SALES_REP_KEY),
		SALES_TO_VENDORS as SALES(VENDOR_KEY) references VENDORS(VENDOR_KEY)
	)
	facts (
		SALES.SALE_AMOUNT as amount comment='Sale amount in dollars',
		SALES.SALE_RECORD as 1 comment='Count of sales transactions',
		SALES.UNITS_SOLD as units comment='Number of units sold'
	)
	dimensions (
		CUSTOMERS.CUSTOMER_INDUSTRY as INDUSTRY with synonyms=('industry','customer type') comment='Customer industry',
		CUSTOMERS.CUSTOMER_KEY as CUSTOMER_KEY,
		CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','client','account') comment='Name of the customer',
		PRODUCTS.CATEGORY_KEY as CATEGORY_KEY with synonyms=('category_id','product_category','category_code','classification_key','group_key','product_group_id') comment='Unique identifier for the product category.',
		PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item') comment='Name of the product',
		PRODUCT_CATEGORY_DIM.CATEGORY_KEY as CATEGORY_KEY with synonyms=('category_id','category_code','product_category_number','category_identifier','classification_key') comment='Unique identifier for a product category.',
		PRODUCT_CATEGORY_DIM.CATEGORY_NAME as CATEGORY_NAME with synonyms=('category_title','product_group','classification_name','category_label','product_category_description') comment='The category to which a product belongs, such as electronics, clothing, or software as a service.',
		PRODUCT_CATEGORY_DIM.VERTICAL as VERTICAL with synonyms=('industry','sector','market','category_group','business_area','domain') comment='The industry or sector in which a product is categorized, such as retail, technology, or manufacturing.',
		REGIONS.REGION_KEY as REGION_KEY,
		REGIONS.REGION_NAME as region_name with synonyms=('region','territory','area') comment='Name of the region',
		SALES.CUSTOMER_KEY as CUSTOMER_KEY,
		SALES.PRODUCT_KEY as PRODUCT_KEY,
		SALES.REGION_KEY as REGION_KEY,
		SALES.SALES_REP_KEY as SALES_REP_KEY,
		SALES.SALE_DATE as date with synonyms=('date','sale date','transaction date') comment='Date of the sale',
		SALES.SALE_ID as SALE_ID,
		SALES.SALE_MONTH as MONTH(date) comment='Month of the sale',
		SALES.SALE_YEAR as YEAR(date) comment='Year of the sale',
		SALES.VENDOR_KEY as VENDOR_KEY,
		SALES_REPS.SALES_REP_KEY as SALES_REP_KEY,
		SALES_REPS.SALES_REP_NAME as REP_NAME with synonyms=('sales rep','representative','salesperson') comment='Name of the sales representative',
		VENDORS.VENDOR_KEY as VENDOR_KEY,
		VENDORS.VENDOR_NAME as vendor_name with synonyms=('vendor','supplier','provider') comment='Name of the vendor'
	)
	metrics (
		SALES.AVERAGE_DEAL_SIZE as AVG(sales.amount) comment='Average deal size',
		SALES.AVERAGE_UNITS_PER_SALE as AVG(sales.units) comment='Average units per sale',
		SALES.TOTAL_DEALS as COUNT(sales.sale_record) comment='Total number of deals',
		SALES.TOTAL_REVENUE as SUM(sales.amount) comment='Total sales revenue',
		SALES.TOTAL_UNITS as SUM(sales.units) comment='Total units sold'
	)
	comment='Semantic view for sales analysis and performance tracking'
	with extension (CA='{"tables":[{"name":"CUSTOMERS","dimensions":[{"name":"CUSTOMER_KEY"},{"name":"CUSTOMER_NAME","sample_values":["Bailey and Sons","Oliver Ltd","Santos-Edwards"]},{"name":"Customer_Industry","sample_values":["Retailer","Tech","Manufacturing"]}]},{"name":"PRODUCTS","dimensions":[{"name":"CATEGORY_KEY","unique":false},{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME","sample_values":["Obrien-Williams Storage","Miller, Smith and Ford Switch","Tran Group Conveyor"]}]},{"name":"PRODUCT_CATEGORY_DIM","dimensions":[{"name":"CATEGORY_KEY","sample_values":["1","2","3"]},{"name":"CATEGORY_NAME","sample_values":["Electronics","Apparel","SaaS"]},{"name":"VERTICAL","sample_values":["Retail","Tech","Manufacturing"]}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME","sample_values":["North","South","West"]}]},{"name":"SALES","dimensions":[{"name":"CUSTOMER_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"},{"name":"SALES_REP_KEY"},{"name":"SALE_DATE","sample_values":["2022-01-01","2022-01-02","2022-01-03"]},{"name":"SALE_ID"},{"name":"SALE_MONTH"},{"name":"SALE_YEAR"},{"name":"VENDOR_KEY"}],"facts":[{"name":"SALE_AMOUNT"},{"name":"SALE_RECORD"},{"name":"UNITS_SOLD"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"AVERAGE_UNITS_PER_SALE"},{"name":"TOTAL_DEALS"},{"name":"TOTAL_REVENUE"},{"name":"TOTAL_UNITS"}]},{"name":"SALES_REPS","dimensions":[{"name":"SALES_REP_KEY"},{"name":"SALES_REP_NAME","sample_values":["Grant Frey","Elizabeth George","Olivia Mcdaniel"]}]},{"name":"VENDORS","dimensions":[{"name":"VENDOR_KEY"},{"name":"VENDOR_NAME","sample_values":["Sullivan and Sons","Smith, Sandoval and Parker","Moore, French and Moore"]}]}],"relationships":[{"name":"PRODUCT_TO_CATEGORY"},{"name":"SALES_TO_CUSTOMERS","relationship_type":"many_to_one"},{"name":"SALES_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"SALES_TO_REGIONS","relationship_type":"many_to_one"},{"name":"SALES_TO_REPS","relationship_type":"many_to_one"},{"name":"SALES_TO_VENDORS","relationship_type":"many_to_one"}]}');


-- ========================================================================
  -- MARKETING SEMANTIC VIEW
  -- ========================================================================
create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.MARKETING_SEMANTIC_VIEW
	tables (
		ACCOUNTS as SF_ACCOUNTS primary key (ACCOUNT_ID) with synonyms=('customers','accounts','clients') comment='Customer account information for revenue analysis',
		CAMPAIGNS as MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('marketing campaigns','campaign data') comment='Marketing campaign performance data',
		CAMPAIGN_DETAILS as CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign details') comment='Campaign dimension with objectives and names',
		CHANNELS as CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('marketing channels','channels') comment='Marketing channel information',
		CONTACTS as SF_CONTACTS primary key (CONTACT_ID) with synonyms=('leads','contacts','prospects') comment='Contact records generated from marketing campaigns',
		OPPORTUNITIES as SF_OPPORTUNITIES primary key (OPPORTUNITY_ID) with synonyms=('deals','opportunities','sales pipeline') comment='Sales opportunities and revenue data',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for campaign-specific analysis',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','markets') comment='Regional information for campaign analysis'
	)
	relationships (
		CAMPAIGNS_TO_CHANNELS as CAMPAIGNS(CHANNEL_KEY) references CHANNELS(CHANNEL_KEY),
		CAMPAIGNS_TO_DETAILS as CAMPAIGNS(CAMPAIGN_KEY) references CAMPAIGN_DETAILS(CAMPAIGN_KEY),
		CAMPAIGNS_TO_PRODUCTS as CAMPAIGNS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		CAMPAIGNS_TO_REGIONS as CAMPAIGNS(REGION_KEY) references REGIONS(REGION_KEY),
		CONTACTS_TO_ACCOUNTS as CONTACTS(ACCOUNT_ID) references ACCOUNTS(ACCOUNT_ID),
		CONTACTS_TO_CAMPAIGNS as CONTACTS(CAMPAIGN_NO) references CAMPAIGNS(CAMPAIGN_FACT_ID),
		CONTACTS_TO_OPPORTUNITIES as CONTACTS(OPPORTUNITY_ID) references OPPORTUNITIES(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_ACCOUNTS as OPPORTUNITIES(ACCOUNT_ID) references ACCOUNTS(ACCOUNT_ID)
	)
	facts (
		CAMPAIGNS.CAMPAIGN_RECORD as 1 comment='Count of campaign activities',
		CAMPAIGNS.CAMPAIGN_SPEND as spend comment='Marketing spend in dollars',
		CAMPAIGNS.IMPRESSIONS as IMPRESSIONS comment='Number of impressions',
		CAMPAIGNS.LEADS_GENERATED as LEADS_GENERATED comment='Number of leads generated',
		CONTACTS.CONTACT_RECORD as 1 comment='Count of contacts generated',
		OPPORTUNITIES.OPPORTUNITY_RECORD as 1 comment='Count of opportunities created',
		OPPORTUNITIES.REVENUE as AMOUNT comment='Opportunity revenue in dollars'
	)
	dimensions (
		ACCOUNTS.ACCOUNT_ID as ACCOUNT_ID,
		ACCOUNTS.ACCOUNT_NAME as ACCOUNT_NAME with synonyms=('customer name','client name','company') comment='Name of the customer account',
		ACCOUNTS.ACCOUNT_TYPE as ACCOUNT_TYPE with synonyms=('customer type','account category') comment='Type of customer account',
		ACCOUNTS.ANNUAL_REVENUE as ANNUAL_REVENUE with synonyms=('customer revenue','company revenue') comment='Customer annual revenue',
		ACCOUNTS.EMPLOYEES as EMPLOYEES with synonyms=('company size','employee count') comment='Number of employees at customer',
		ACCOUNTS.INDUSTRY as INDUSTRY with synonyms=('industry','sector') comment='Customer industry',
		ACCOUNTS.SALES_CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('Customer No','Customer ID') comment='This is the customer key thank links the Salesforce account to customers table.',
		CAMPAIGNS.CAMPAIGN_DATE as date with synonyms=('date','campaign date') comment='Date of the campaign activity',
		CAMPAIGNS.CAMPAIGN_FACT_ID as CAMPAIGN_FACT_ID,
		CAMPAIGNS.CAMPAIGN_KEY as CAMPAIGN_KEY,
		CAMPAIGNS.CAMPAIGN_MONTH as MONTH(date) comment='Month of the campaign',
		CAMPAIGNS.CAMPAIGN_YEAR as YEAR(date) comment='Year of the campaign',
		CAMPAIGNS.CHANNEL_KEY as CHANNEL_KEY,
		CAMPAIGNS.PRODUCT_KEY as PRODUCT_KEY with synonyms=('product_id','product identifier') comment='Product identifier for campaign targeting',
		CAMPAIGNS.REGION_KEY as REGION_KEY,
		CAMPAIGN_DETAILS.CAMPAIGN_KEY as CAMPAIGN_KEY,
		CAMPAIGN_DETAILS.CAMPAIGN_NAME as CAMPAIGN_NAME with synonyms=('campaign','campaign title') comment='Name of the marketing campaign',
		CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE as OBJECTIVE with synonyms=('objective','goal','purpose') comment='Campaign objective',
		CHANNELS.CHANNEL_KEY as CHANNEL_KEY,
		CHANNELS.CHANNEL_NAME as CHANNEL_NAME with synonyms=('channel','marketing channel') comment='Name of the marketing channel',
		CONTACTS.ACCOUNT_ID as ACCOUNT_ID,
		CONTACTS.CAMPAIGN_NO as CAMPAIGN_NO,
		CONTACTS.CONTACT_ID as CONTACT_ID,
		CONTACTS.DEPARTMENT as DEPARTMENT with synonyms=('department','business unit') comment='Contact department',
		CONTACTS.EMAIL as EMAIL with synonyms=('email','email address') comment='Contact email address',
		CONTACTS.FIRST_NAME as FIRST_NAME with synonyms=('first name','contact name') comment='Contact first name',
		CONTACTS.LAST_NAME as LAST_NAME with synonyms=('last name','surname') comment='Contact last name',
		CONTACTS.LEAD_SOURCE as LEAD_SOURCE with synonyms=('lead source','source') comment='How the contact was generated',
		CONTACTS.OPPORTUNITY_ID as OPPORTUNITY_ID,
		CONTACTS.TITLE as TITLE with synonyms=('job title','position') comment='Contact job title',
		OPPORTUNITIES.ACCOUNT_ID as ACCOUNT_ID,
		OPPORTUNITIES.CLOSE_DATE as CLOSE_DATE with synonyms=('close date','expected close') comment='Expected or actual close date',
		OPPORTUNITIES.OPPORTUNITY_ID as OPPORTUNITY_ID,
		OPPORTUNITIES.OPPORTUNITY_LEAD_SOURCE as lead_source with synonyms=('opportunity source','deal source') comment='Source of the opportunity',
		OPPORTUNITIES.OPPORTUNITY_NAME as OPPORTUNITY_NAME with synonyms=('deal name','opportunity title') comment='Name of the sales opportunity',
		OPPORTUNITIES.OPPORTUNITY_STAGE as STAGE_NAME comment='Stage name of the opportinity. Closed Won indicates an actual sale with revenue',
		OPPORTUNITIES.OPPORTUNITY_TYPE as TYPE with synonyms=('deal type','opportunity type') comment='Type of opportunity',
		OPPORTUNITIES.SALES_SALE_ID as SALE_ID with synonyms=('sales id','invoice no') comment='Sales_ID for sales_fact table that links this opp to a sales record.',
		PRODUCTS.PRODUCT_CATEGORY as CATEGORY_NAME with synonyms=('category','product category') comment='Category of the product',
		PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		PRODUCTS.PRODUCT_NAME as PRODUCT_NAME with synonyms=('product','item','product title') comment='Name of the product being promoted',
		PRODUCTS.PRODUCT_VERTICAL as VERTICAL with synonyms=('vertical','industry') comment='Business vertical of the product',
		REGIONS.REGION_KEY as REGION_KEY,
		REGIONS.REGION_NAME as REGION_NAME with synonyms=('region','market','territory') comment='Name of the region'
	)
	metrics (
		CAMPAIGNS.AVERAGE_SPEND as AVG(CAMPAIGNS.spend) comment='Average campaign spend',
		CAMPAIGNS.TOTAL_CAMPAIGNS as COUNT(CAMPAIGNS.campaign_record) comment='Total number of campaign activities',
		CAMPAIGNS.TOTAL_IMPRESSIONS as SUM(CAMPAIGNS.impressions) comment='Total impressions across campaigns',
		CAMPAIGNS.TOTAL_LEADS as SUM(CAMPAIGNS.leads_generated) comment='Total leads generated from campaigns',
		CAMPAIGNS.TOTAL_SPEND as SUM(CAMPAIGNS.spend) comment='Total marketing spend',
		CONTACTS.TOTAL_CONTACTS as COUNT(CONTACTS.contact_record) comment='Total contacts generated from campaigns',
		OPPORTUNITIES.AVERAGE_DEAL_SIZE as AVG(OPPORTUNITIES.revenue) comment='Average opportunity size from marketing',
		OPPORTUNITIES.CLOSED_WON_REVENUE as SUM(CASE WHEN OPPORTUNITIES.opportunity_stage = 'Closed Won' THEN OPPORTUNITIES.revenue ELSE 0 END) comment='Revenue from closed won opportunities',
		OPPORTUNITIES.TOTAL_OPPORTUNITIES as COUNT(OPPORTUNITIES.opportunity_record) comment='Total opportunities from marketing',
		OPPORTUNITIES.TOTAL_REVENUE as SUM(OPPORTUNITIES.revenue) comment='Total revenue from marketing-driven opportunities'
	)
	comment='Enhanced semantic view for marketing campaign analysis with complete revenue attribution and ROI tracking'
	with extension (CA='{"tables":[{"name":"ACCOUNTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"ACCOUNT_NAME"},{"name":"ACCOUNT_TYPE"},{"name":"ANNUAL_REVENUE"},{"name":"EMPLOYEES"},{"name":"INDUSTRY"},{"name":"SALES_CUSTOMER_KEY"}]},{"name":"CAMPAIGNS","dimensions":[{"name":"CAMPAIGN_DATE"},{"name":"CAMPAIGN_FACT_ID"},{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_MONTH"},{"name":"CAMPAIGN_YEAR"},{"name":"CHANNEL_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"}],"facts":[{"name":"CAMPAIGN_RECORD"},{"name":"CAMPAIGN_SPEND"},{"name":"IMPRESSIONS"},{"name":"LEADS_GENERATED"}],"metrics":[{"name":"AVERAGE_SPEND"},{"name":"TOTAL_CAMPAIGNS"},{"name":"TOTAL_IMPRESSIONS"},{"name":"TOTAL_LEADS"},{"name":"TOTAL_SPEND"}]},{"name":"CAMPAIGN_DETAILS","dimensions":[{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_NAME"},{"name":"CAMPAIGN_OBJECTIVE"}]},{"name":"CHANNELS","dimensions":[{"name":"CHANNEL_KEY"},{"name":"CHANNEL_NAME"}]},{"name":"CONTACTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_NO"},{"name":"CONTACT_ID"},{"name":"DEPARTMENT"},{"name":"EMAIL"},{"name":"FIRST_NAME"},{"name":"LAST_NAME"},{"name":"LEAD_SOURCE"},{"name":"OPPORTUNITY_ID"},{"name":"TITLE"}],"facts":[{"name":"CONTACT_RECORD"}],"metrics":[{"name":"TOTAL_CONTACTS"}]},{"name":"OPPORTUNITIES","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CLOSE_DATE"},{"name":"OPPORTUNITY_ID"},{"name":"OPPORTUNITY_LEAD_SOURCE"},{"name":"OPPORTUNITY_NAME"},{"name":"OPPORTUNITY_STAGE","sample_values":["Closed Won","Perception Analysis","Qualification"]},{"name":"OPPORTUNITY_TYPE"},{"name":"Sales_Sale_ID"}],"facts":[{"name":"OPPORTUNITY_RECORD"},{"name":"REVENUE"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CLOSED_WON_REVENUE"},{"name":"TOTAL_OPPORTUNITIES"},{"name":"TOTAL_REVENUE"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_CATEGORY"},{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME"},{"name":"PRODUCT_VERTICAL"}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME"}]}],"relationships":[{"name":"CAMPAIGNS_TO_CHANNELS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_DETAILS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_REGIONS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_CAMPAIGNS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_OPPORTUNITIES","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_ACCOUNTS","relationship_type":"many_to_one"}]}');




  -- ========================================================================
  -- HR SEMANTIC VIEW
  -- ========================================================================
create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.HR_SEMANTIC_VIEW
	tables (
		DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('departments','business units') comment='Department dimension for organizational analysis',
		EMPLOYEES as EMPLOYEE_DIM primary key (EMPLOYEE_KEY) with synonyms=('employees','staff','workforce') comment='Employee dimension with personal information',
		HR_RECORDS as HR_EMPLOYEE_FACT primary key (HR_FACT_ID) with synonyms=('hr data','employee records') comment='HR employee fact data for workforce analysis',
		JOBS as JOB_DIM primary key (JOB_KEY) with synonyms=('job titles','positions','roles') comment='Job dimension with titles and levels',
		LOCATIONS as LOCATION_DIM primary key (LOCATION_KEY) with synonyms=('locations','offices','sites') comment='Location dimension for geographic analysis'
	)
	relationships (
		HR_TO_DEPARTMENTS as HR_RECORDS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
		HR_TO_EMPLOYEES as HR_RECORDS(EMPLOYEE_KEY) references EMPLOYEES(EMPLOYEE_KEY),
		HR_TO_JOBS as HR_RECORDS(JOB_KEY) references JOBS(JOB_KEY),
		HR_TO_LOCATIONS as HR_RECORDS(LOCATION_KEY) references LOCATIONS(LOCATION_KEY)
	)
	facts (
		HR_RECORDS.ATTRITION_FLAG as attrition_flag with synonyms=('turnover_indicator','employee_departure_flag','separation_flag','employee_retention_status','churn_status','employee_exit_indicator') comment='Attrition flag. value is 0 if employee is currently active. 1 if employee quit & left the company. Always filter by 0 to show active employees unless specified otherwise',
		HR_RECORDS.EMPLOYEE_RECORD as 1 comment='Count of employee records',
		HR_RECORDS.EMPLOYEE_SALARY as salary comment='Employee salary in dollars'
	)
	dimensions (
		DEPARTMENTS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','business unit','division') comment='Name of the department',
		EMPLOYEES.EMPLOYEE_KEY as EMPLOYEE_KEY,
		EMPLOYEES.EMPLOYEE_NAME as employee_name with synonyms=('employee','staff member','person','sales rep','manager','director','executive') comment='Name of the employee',
		EMPLOYEES.GENDER as gender with synonyms=('gender','sex') comment='Employee gender',
		EMPLOYEES.HIRE_DATE as hire_date with synonyms=('hire date','start date') comment='Date when employee was hired',
		HR_RECORDS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		HR_RECORDS.EMPLOYEE_KEY as EMPLOYEE_KEY,
		HR_RECORDS.HR_FACT_ID as HR_FACT_ID,
		HR_RECORDS.JOB_KEY as JOB_KEY,
		HR_RECORDS.LOCATION_KEY as LOCATION_KEY,
		HR_RECORDS.RECORD_DATE as date with synonyms=('date','record date') comment='Date of the HR record',
		HR_RECORDS.RECORD_MONTH as MONTH(date) comment='Month of the HR record',
		HR_RECORDS.RECORD_YEAR as YEAR(date) comment='Year of the HR record',
		JOBS.JOB_KEY as JOB_KEY,
		JOBS.JOB_LEVEL as job_level with synonyms=('level','grade','seniority') comment='Job level or grade',
		JOBS.JOB_TITLE as job_title with synonyms=('job title','position','role') comment='Employee job title',
		LOCATIONS.LOCATION_KEY as LOCATION_KEY,
		LOCATIONS.LOCATION_NAME as location_name with synonyms=('location','office','site') comment='Work location'
	)
	metrics (
		HR_RECORDS.ATTRITION_COUNT as SUM(hr_records.attrition_flag) comment='Number of employees who left',
		HR_RECORDS.AVG_SALARY as AVG(hr_records.employee_salary) comment='average employee salary',
		HR_RECORDS.TOTAL_EMPLOYEES as COUNT(hr_records.employee_record) comment='Total number of employees',
		HR_RECORDS.TOTAL_SALARY_COST as SUM(hr_records.EMPLOYEE_SALARY) comment='Total salary cost'
	)
	comment='Semantic view for HR analytics and workforce management'
	with extension (CA='{"tables":[{"name":"DEPARTMENTS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"DEPARTMENT_NAME","sample_values":["Finance","Accounting","Treasury"]}]},{"name":"EMPLOYEES","dimensions":[{"name":"EMPLOYEE_KEY"},{"name":"EMPLOYEE_NAME","sample_values":["Grant Frey","Elizabeth George","Olivia Mcdaniel"]},{"name":"GENDER"},{"name":"HIRE_DATE"}]},{"name":"HR_RECORDS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"EMPLOYEE_KEY"},{"name":"HR_FACT_ID"},{"name":"JOB_KEY"},{"name":"LOCATION_KEY"},{"name":"RECORD_DATE"},{"name":"RECORD_MONTH"},{"name":"RECORD_YEAR"}],"facts":[{"name":"ATTRITION_FLAG","sample_values":["0","1"]},{"name":"EMPLOYEE_RECORD"},{"name":"EMPLOYEE_SALARY"}],"metrics":[{"name":"ATTRITION_COUNT"},{"name":"AVG_SALARY"},{"name":"TOTAL_EMPLOYEES"},{"name":"TOTAL_SALARY_COST"}]},{"name":"JOBS","dimensions":[{"name":"JOB_KEY"},{"name":"JOB_LEVEL"},{"name":"JOB_TITLE"}]},{"name":"LOCATIONS","dimensions":[{"name":"LOCATION_KEY"},{"name":"LOCATION_NAME"}]}],"relationships":[{"name":"HR_TO_DEPARTMENTS","relationship_type":"many_to_one"},{"name":"HR_TO_EMPLOYEES","relationship_type":"many_to_one"},{"name":"HR_TO_JOBS","relationship_type":"many_to_one"},{"name":"HR_TO_LOCATIONS","relationship_type":"many_to_one"}],"verified_queries":[{"name":"List of all active employees","question":"List of all active employees","sql":"select\\n  h.employee_key,\\n  e.employee_name,\\nfrom\\n  employees e\\n  left join hr_records h on e.employee_key = h.employee_key\\ngroup by\\n  all\\nhaving\\n  sum(h.attrition_flag) = 0;","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846263},{"name":"List of all inactive employees","question":"List of all inactive employees","sql":"SELECT\\n  h.employee_key,\\n  e.employee_name\\nFROM\\n  employees AS e\\n  LEFT JOIN hr_records AS h ON e.employee_key = h.employee_key\\nGROUP BY\\n  ALL\\nHAVING\\n  SUM(h.attrition_flag) > 0","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846300}],"custom_instructions":"- Each employee can have multiple hr_employee_fact records. \\n- Only one hr_employee_fact record per employee is valid and that is the one which has the highest date value."}');
  -- ========================================================================
  -- VERIFICATION
  -- ========================================================================

  -- Show all semantic views
  SHOW SEMANTIC VIEWS;

  -- Show dimensions for each semantic view
  SHOW SEMANTIC DIMENSIONS;

  -- Show metrics for each semantic view
  SHOW SEMANTIC METRICS; 







    -- ========================================================================
    -- UNSTRUCTURED DATA
    -- ========================================================================
create or replace table parsed_content as 
select 
   
    relative_path, 
    BUILD_STAGE_FILE_URL('@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE', relative_path) as file_url,
     TO_File(BUILD_STAGE_FILE_URL('@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE', relative_path) ) file_object,
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                                    @SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE,
                                    relative_path,
                                    {'mode':'LAYOUT'}
                                    ):content::string as Content

    
    from directory(@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE) 
where relative_path ilike 'unstructured_docs/%.pdf' ;

--select *, GET_PATH(PARSE_JSON(content), 'content')::string as extracted_content from parsed_content;


    -- Switch to admin role for remaining operations
    USE ROLE SF_Intelligence_Demo;

    -- Create search service for finance documents
    -- This enables semantic search over finance-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_finance_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title, -- Extract filename as title
                content
            FROM parsed_content
            WHERE relative_path ilike '%/finance/%'
        );
    
    -- Create search service for HR documents
    -- This enables semantic search over HR-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_hr_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/hr/%'
        );

    -- Create search service for marketing documents
    -- This enables semantic search over marketing-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_marketing_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/marketing/%'
        );

    -- Create search service for sales documents
    -- This enables semantic search over sales-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_sales_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/sales/%'
        );


use role sf_intelligence_demo;


  -- NETWORK rule is part of db schema
CREATE OR REPLACE NETWORK RULE Snowflake_intelligence_WebAccessRule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443');


use role accountadmin;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION Snowflake_intelligence_ExternalAccess_Integration
  ALLOWED_NETWORK_RULES = (Snowflake_intelligence_WebAccessRule)
  ENABLED = true;



GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SF_Intelligence_Demo;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;

use role SF_Intelligence_Demo;
-- CREATES A SNOWFLAKE INTELLIGENCE AGENT WITH MULTIPLE TOOLS

-- Create stored procedure to generate presigned URLs for files in internal stages
CREATE OR REPLACE PROCEDURE Get_File_Presigned_URL_SP(
    RELATIVE_FILE_PATH STRING, 
    EXPIRATION_MINS INTEGER DEFAULT 60
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Generates a presigned URL for a file in the static @INTERNAL_DATA_STAGE. Input is the relative file path.'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
    stage_name STRING DEFAULT '@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE';
BEGIN
    expiration_seconds := EXPIRATION_MINS * 60;

    sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ' || '''' || RELATIVE_FILE_PATH || '''' || ', ' || expiration_seconds || ') AS url';
    
    EXECUTE IMMEDIATE :sql_stmt;
    
    
    SELECT "URL"
    INTO :presigned_url
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    RETURN :presigned_url;
END;
$$;

-- Create stored procedure to send emails to verified recipients in Snowflake
CREATE OR REPLACE PROCEDURE send_mail(recipient TEXT, subject TEXT, text TEXT)
RETURNS TEXT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_mail'
AS
$$
def send_mail(session, recipient, subject, text):
    session.call(
        'SYSTEM$SEND_EMAIL',
        'ai_email_int',
        recipient,
        subject,
        text,
        'text/html'
    )
    return f'Email was sent to {recipient} with subject: "{subject}".'
$$;

-- Create notification integration to allow emails to be sent from Snowflake
use role accountadmin;

CREATE OR REPLACE NOTIFICATION INTEGRATION ai_email_int
  TYPE=EMAIL
  ENABLED=TRUE;

GRANT USAGE ON INTEGRATION ai_email_int TO ROLE SF_Intelligence_Demo;

use role SF_Intelligence_Demo;

-- Create function to scrape web pages
CREATE OR REPLACE FUNCTION Web_scrape(weburl STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
HANDLER = 'get_page'
EXTERNAL_ACCESS_INTEGRATIONS = (Snowflake_intelligence_ExternalAccess_Integration)
PACKAGES = ('requests', 'beautifulsoup4')
--SECRETS = ('cred' = oauth_token )
AS
$$
import _snowflake
import requests
from bs4 import BeautifulSoup

def get_page(weburl):
  url = f"{weburl}"
  response = requests.get(url)
  soup = BeautifulSoup(response.text)
  return soup.get_text()
$$;


CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.Company_Chatbot_Agent_Retail
WITH PROFILE='{ "display_name": "1-Company Chatbot Agent - Retail" }'
    COMMENT=$$ This is an agent that can answer questions about company specific Sales, Marketing, HR & Finance questions. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are a data analyst who has access to sales, finance, marketing & HR datamarts.  If user does not specify a date range assume it for year 2025. Leverage data from all domains to analyse & answer user questions. Provide visualizations if possible. Trendlines should default to linecharts, Categories Barchart.",
    "orchestration": "Use cortex search for known entities and pass the results to cortex analyst for detailed analysis.\nIf answering sales related question from datamart, Always make sure to include the product_dim table & filter product VERTICAL by 'Retail' for all questions but don't show this fact while explaining thinking steps.\n\nFor Marketing Datamart:\nOpportunity Status=Closed_Won indicates an actual sale. \nSalesID in marketing datamart links an opportunity to a Sales record in Sales Datamart SalesID columns\n\n\n",
    "sample_questions": [
      {
        "question": "What are our monthly sales last 12 months?"
      }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Finance Datamart",
        "description": "Allows users to query finance data for a company in terms of revenue & expenses."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Sales Datamart",
        "description": "Allows users to query Sales data for a company in terms of Sales data such as products, sales reps & etc. "
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query HR Datamart",
        "description": "Allows users to query HR data for a company in terms of HR related employee data. employee_name column also contains names of sales_reps."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Marketing Datamart",
        "description": "Allows users to query Marketing data in terms of campaigns, channels, impressions, spend & etc."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Internal Documents: Finance",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Internal Documents: HR",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Internal Documents: Sales",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Internal Documents: Marketing",
        "description": "This tools should be used to search unstructured docs related to marketing department.\n\nAny reference docs in ID columns should be passed to Dynamic URL tool to generate a downloadable URL for users in the response"
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool should be used if the user wants to analyse contents of a given web page. This tool will use a web url (https or https) as input and will return the text content of that web page for further analysis",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Agent should ask web url ( that includes http:// or https:// ). It will scrape text from the given url and return as a result.",
              "type": "string"
            }
          },
          "required": [
            "weburl"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Send_Emails",
        "description": "This tool is used to send emails to a email recipient. It can take an email, subject & content as input to send the email. Always use HTML formatted content for the emails.",
        "input_schema": {
          "type": "object",
          "properties": {
            "recipient": {
              "description": "recipient of email",
              "type": "string"
            },
            "subject": {
              "description": "subject of email",
              "type": "string"
            },
            "text": {
              "description": "content of email",
              "type": "string"
            }
          },
          "required": [
            "text",
            "recipient",
            "subject"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Dynamic_Doc_URL_Tool",
        "description": "This tools uses the ID Column coming from Cortex Search tools for reference docs and returns a temp URL for users to view & download the docs.\n\nReturned URL should be presented as a HTML Hyperlink where doc title should be the text and out of this tool should be the url.\n\nURL format for PDF docs that are are like this which has no PDF in the url. Create the Hyperlink format so the PDF doc opens up in a browser instead of downloading the file.\nhttps://domain/path/unique_guid",
        "input_schema": {
          "type": "object",
          "properties": {
            "expiration_mins": {
              "description": "default should be 5",
              "type": "number"
            },
            "relative_file_path": {
              "description": "This is the ID Column value Coming from Cortex Search tool.",
              "type": "string"
            }
          },
          "required": [
            "expiration_mins",
            "relative_file_path"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "Dynamic_Doc_URL_Tool": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SNOW_INTELLIGENCE_DEMO_WH"
      },
      "identifier": "SF_AI_DEMO.DEMO_SCHEMA.GET_FILE_PRESIGNED_URL_SP",
      "name": "GET_FILE_PRESIGNED_URL_SP(VARCHAR, DEFAULT NUMBER)",
      "type": "procedure"
    },
    "Query Finance Datamart": {
      "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.FINANCE_SEMANTIC_VIEW"
    },
    "Query HR Datamart": {
      "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.HR_SEMANTIC_VIEW"
    },
    "Query Marketing Datamart": {
      "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.MARKETING_SEMANTIC_VIEW"
    },
    "Query Sales Datamart": {
      "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.SALES_SEMANTIC_VIEW"
    },
    "Search Internal Documents: Finance": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_FINANCE_DOCS",
      "title_column": "TITLE"
    },
    "Search Internal Documents: HR": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_HR_DOCS",
      "title_column": "TITLE"
    },
    "Search Internal Documents: Marketing": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_MARKETING_DOCS",
      "title_column": "TITLE"
    },
    "Search Internal Documents: Sales": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_SALES_DOCS",
      "title_column": "TITLE"
    },
    "Send_Emails": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SNOW_INTELLIGENCE_DEMO_WH"
      },
      "identifier": "SF_AI_DEMO.DEMO_SCHEMA.SEND_MAIL",
      "name": "SEND_MAIL(VARCHAR, VARCHAR, VARCHAR)",
      "type": "procedure"
    },
    "Web_scraper": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SNOW_INTELLIGENCE_DEMO_WH"
      },
      "identifier": "SF_AI_DEMO.DEMO_SCHEMA.WEB_SCRAPE",
      "name": "WEB_SCRAPE(VARCHAR)",
      "type": "function"
    }
  }
}
$$;

