library(tidyverse)
library(odbc)
library(DBI)
library(dbplyr)

con <- odbc::dbConnect(odbc::odbc(),
                       driver="ODBC Driver 18 for SQL Server",
                       database="OCHCO",
                       server="alteryxwkr.ndc.nasa.gov",
                       port=1433,
                       trusted_connection = "yes")

payPeriod <- '202406'

per_org_data_tbl <- tbl(con, in_schema("pdw_dev_trusted","personal_organization_data")) %>% filter(current_pay_period == payPeriod)
daily_charges_tbl <- tbl(con, in_schema("webtads_dev_trusted", "daily_charges")) %>% filter(yrpp == payPeriod)
leave_hours_tbl <- tbl(con, in_schema("webtads_dev_trusted", "leave_hour_types"))
telework_request_tbl <- tbl(con, in_schema("webtads_dev_trusted", "telework_requests")) %>% filter(current_pay_period == payPeriod)
# national capital region 
# uses State and County codes in the NCR as defined in OPMs FAQ
tempNCR_df <- per_org_data_tbl %>%
   filter(str_like(duty_station, "11%001" ) | str_like(duty_station, "24%031" ) | str_like(duty_station, "24%033" ) | str_like(duty_station, "51%013" )
           | str_like(duty_station, "51%059" ) | str_like(duty_station, "51%107" ) | str_like(duty_station, "51%153" ) | str_like(duty_station, "510040%" )
           | str_like(duty_station, "510900%" ) | str_like(duty_station, "510930%" ) | str_like(duty_station, "511549%" ) | str_like(duty_station, "511550%" )) %>% 
    distinct(uupic) %>% 
    collect()
# insight into how many employees in NCR, not used in spreadsheet
tempNCR_df %>% summarise(n())
tempNCR_df
# NCR teleworkers
uupics <- tempNCR_df$uupic
tempNCR_TW_df <- daily_charges_tbl %>% 
    filter(telework_flag_indicator == "Y", remote_worker_indicator == "N") %>% 
    filter(uupic %IN% uupics) %>% 
    distinct(uupic) %>% 
    collect()
#used later in code, column P
uupics_ncr_tw <- tempNCR_TW_df$uupic
tmepNCR_TW <- tempNCR_TW_df %>% summarise(n())

# assigned to HQ
# Uses daily charges tbl
tempHQ_df <- daily_charges_tbl %>% 
    filter(str_like(center_text, "HQ")) %>% 
    distinct(uupic) %>% 
    collect() %>%
    summarise(n())
tempHQ_df

# assigned to OIG
# Uses per_org_data_tbl 
tempOIG_df <- per_org_data_tbl %>% 
    filter(str_like(center, "OIG")) %>% 
    distinct(uupic) %>%
    collect() %>%
    summarise(n())
tempOIG_df
##############################################################
# Pay Period End Date
ppd_enddate <- daily_charges_tbl %>% 
    distinct(payperiod_end_date) %>%
    collect()
ppd_enddate

# verify headcount for civil servants onboard
# D. Total # of Employees On Board at End of Pay Period, Nationally

cs_count <- daily_charges_tbl %>% 
    filter(dutystatus == 'A' | dutystatus == 'L') %>% 
    distinct(uupic) %>% 
    collect() %>% 
    summarise(n())
cs_count

# total number of employees working remotely at the end of the pay period, nationally
# E. Total # of Employee Working Remotely at End of Pay Period, Nationally

emp_nation_tw <- telework_request_tbl %>% 
    filter(duty_status == "Active" | duty_status == "LWOP") %>% 
    filter(remote_agreement == "Y") %>% 
    distinct(uupic) %>% 
    collect() %>% 
    summarise(n())
emp_nation_tw

# of employees on board in the National Capital Region
# F. Total # of Employees On Board at end of Pay Period, in the National Capital Region (NCR)

emp_ncr <- daily_charges_tbl %>% 
    filter(dutystatus == 'A' | dutystatus == 'L') %>% 
    filter(uupic %IN% uupics) %>% 
    distinct(uupic) %>% 
    collect() %>% 
    summarise(n())
emp_ncr

# verify # of employees teleworked during the pay period, nationally
# G. Total # of Employees who Teleworked During the Pay Period, Nationally

emp_tw <- daily_charges_tbl %>% 
    filter(dutystatus == 'A' | dutystatus == 'L') %>%
    filter(telework_flag_indicator == "Y") %>% 
    filter(remote_worker_indicator == "N") %>% 
    distinct(uupic) %>% 
    collect() %>% 
    summarise(n())
emp_tw

# of employees who teleworked during the pay period, National Capital Region
# H. Total # of Employees who Teleworked During Pay Period, in the NCR

ncr_tw <- tempNCR_TW_df %>% summarise(n())

# of employees assigned to Agency HQ and HQ-Equivalent organizations (taken to mean HQ center assignment in PDW)
# I. Total # of Employees  Assigned to Agency HQ and HQ-Equivalent Organizations

emp_hq <- daily_charges_tbl %>% 
    filter(center_text == "HQ") %>% 
    distinct(uupic) %>% 
    collect() %>% 
    summarise(n())
emp_hq

# validate regular payroll hours worked nationally
# J. Total # of Regular Payroll Hours - All Employees, Nationally

hrs_national <- daily_charges_tbl %>% 
    left_join(leave_hours_tbl, by = join_by(hour_type == `HourType Name`)) %>%
    filter(str_like(hour_type, "REG%")) %>% 
    collect() %>% 
    summarise(hrs_national = sum(hours_charged)) 
hrs_national    
    
# validate regular payroll hours coded as telework worked nationally
# K. Total # of Regular Hours Coded as Telework - All Employees, Nationally

tw_hrs_national <- daily_charges_tbl %>% 
    filter(str_like(hour_type, "REG%")) %>%
    filter(telework_flag_indicator == "Y") %>% 
    filter(remote_worker_indicator == "N") %>% 
    collect() %>% 
    summarize(tw_hrs = sum(hours_charged))
tw_hrs_national

# L. % of Hours Performed In-Person - All Employees, Nationally 

in_person_hrs_nation <- (hrs_national - tw_hrs_national)/hrs_national
in_person_hrs_nation

# total regular hours in NCR
# M. Total # of Regular Payroll Hours - Employees with Duty Stations in the NCR

hrs_ncr <- daily_charges_tbl %>% 
    filter(str_like(hour_type, "REG%")) %>%
    filter(uupic %IN% uupics) %>% 
    collect() %>% 
    summarise(hrs_ncr = sum(hours_charged))
hrs_ncr

# telework hours for NCR
# N. Total # of Regular Hours Coded as Telework - Employees with Duty Stations in the NCR

tw_hrs_ncr <- daily_charges_tbl %>%
    filter(str_like(hour_type, "REG%")) %>%
    filter(telework_flag_indicator == "Y") %>% 
    filter(remote_worker_indicator == "N") %>% 
    filter(uupic %IN% uupics) %>% 
    collect() %>% 
    summarise(tw_hrs_ncr = sum(hours_charged))
tw_hrs_ncr

# O. % of Hours Performed In-Person - Employees with Duty Stations in the NCR

in_person_hrs_ncr <- (hrs_ncr - tw_hrs_ncr)/hrs_ncr
in_person_hrs_ncr

# total regular hours in NCR, teleworkers only
# P. Total # of Regular Payroll Hours - Employees with Duty Stations in the NCR who Teleworked in the Pay Period

hrs_ncr_tw_emp <- daily_charges_tbl %>% 
    filter(str_like(hour_type, "REG%")) %>%
    filter(uupic %IN% uupics_ncr_tw) %>% 
    collect() %>% 
    summarise(hrs_ncr_tw_emp = sum(hours_charged))
hrs_ncr_tw_emp

# telework hours
# Q. Total # of Regular Hours Coded as Telework - Employees with Duty Stations in the NCR who Teleworked in the Pay Period
# Same calculation as Column N
# tw_hrs_ncr <- daily_charges_tbl %>%
#     filter(str_like(hour_type, "REG%")) %>%
#     filter(telework_flag_indicator == "Y") %>% 
#     filter(remote_worker_indicator == "N") %>% 
#     filter(uupic %IN% uupics) %>% 
#     collect() %>% 
#     summarise(tw_hrs_ncr = sum(hours_charged))
tw_hrs_ncr

# R. % of Hours Performed In-Person - Employees with Duty Stations in the NCR who Teleworked in the Pay Period
in_person_ncr_tw_emp <- (hrs_ncr_tw_emp - tw_hrs_ncr)/hrs_ncr_tw_emp

# total regular hours for HQ orgs
# S. Total # of Regular Payroll Hours - Employees Assigned to Agency HQ and HQ-Equivalent Organizations

hrs_hq <- daily_charges_tbl %>% 
    filter(str_like(hour_type, "REG%")) %>%
    filter(center_text == "HQ") %>%
    collect() %>% 
    summarise(hrs_hq = sum(hours_charged))
hrs_hq

# telework hours for  HQ
# T. Total # of Regular Hours Coded as Telework - Employees Assigned to Agency HQ and HQ-Equivalent Organizations

tw_hrs_hq <- daily_charges_tbl %>% 
    filter(str_like(hour_type, "REG%")) %>%
    filter(telework_flag_indicator == "Y") %>% 
    filter(remote_worker_indicator == "N") %>% 
    filter(center_text == "HQ") %>%
    collect() %>% 
    summarise(tw_hrs_hq = sum(hours_charged))
tw_hrs_hq    
    
# U. % of Hours Performed In-Person - Employees Assigned to Agency HQ and HQ-Equivalent Organizations
in_person_hq_tw_emp <- (hrs_hq - tw_hrs_hq)/hrs_hq    
in_person_hq_tw_emp
    
# Create a dataframe of all the results    
opm_twrw_data_call <- tribble(~"Period End Date",
                              ~"D. Total # of Employees",
                              ~"E. Total # of TW Employees",
                              ~"F. Total # of Employees - NCR",
                              ~"G. Employees TW Nationally",
                              ~"H. Employees TW NCR", 
                              ~"I. Total # of Employees - HQ",
                              ~"J. Total # of Regular Payroll Hours",
                              ~"K. Total # of Regular Hours Coded as Telework",
                              ~"L. % of Hours Performed In-Person",
                              ~"M. Total # of Regular Payroll Hours - NCR",
                              ~"N. Total # of Regular Hours Coded as Telework - NCR",
                              ~"O. % of Hours Performed In-Person - NCR",
                              ~"P. Total # of Regular Payroll Hours - NCR who TW",
                              ~"Q. Total # of Regular Hours Coded as Telework - NCR who TW",
                              ~"R. % of Hours Performed In-Person - NCR who TW",
                              ~"S. Total # of Regular Payroll Hours - HQ Emp",
                              ~"T. Total # of Regular Hours Coded as Telework - HQ Emp",
                              ~"U. % of Hours Performed In-Person - HQ",
                              ppd_enddate$payperiod_end_date,
                              cs_count$`n()`,
                              emp_nation_tw$`n()`,
                              emp_ncr$`n()`,
                              emp_tw$`n()`,
                              ncr_tw$`n()`,
                              emp_hq$`n()`,
                              hrs_national$hrs_national,
                              tw_hrs_national$tw_hrs,
                              in_person_hrs_nation$hrs_national,
                              hrs_ncr$hrs_ncr,
                              tw_hrs_ncr$tw_hrs_ncr,
                              in_person_hrs_ncr$hrs_ncr,
                              hrs_ncr_tw_emp$hrs_ncr_tw_emp,
                              tw_hrs_ncr$tw_hrs_ncr,
                              in_person_ncr_tw_emp$hrs_ncr_tw_emp,
                              hrs_hq$hrs_hq,
                              tw_hrs_hq$tw_hrs_hq,
                              in_person_hq_tw_emp$hrs_hq) 


#Create and append to an excel worksheet
library(openxlsx2)
# already created
# write_xlsx(x = opm_twrw_data_call, file = "opm_twrw_data_call.xlsx")
# load the wb from file
wb <- wb_load(file = "opm_twrw_data_call.xlsx")
# convert to dataframe in order to get current row count
x <- wb_to_df(wb)
r_count <- nrow(x)
# set the start row to a value after the last row in the current wb
start_row <- r_count + 2
# add the row just created for the Pay Period
wb <- wb_add_data(wb, x = opm_twrw_data_call, start_row = start_row, col_names = FALSE )
# save the excel file
wb$save("opm_twrw_data_call.xlsx")
# update the data frame with the new data
x <- wb_to_df(wb)
