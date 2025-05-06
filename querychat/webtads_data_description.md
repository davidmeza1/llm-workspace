The data was from the Payroll system for one pay period, 202507. The pay period 
is called current_pay_period in the table. The table show daily charges for the
pay period for each employee, identified by the uupic variable. Below is a list
of the variable and their meaning.

- datetime_rds_last_updated: when the data was last updated
- uupic: unique identifier, represents an employee
- current_pay_period: the pay period being for the daily charges
- center: Assigned NASA Center of the employee
- core_role: role type for employee
- day_of_pay_period: the numeric number of the day of pay period. 1 is the first Sunday of the period. 14 is the end.
- day_of_week: The day of the week the charge was applied to
- duty_status: employee status, could be Active or LWOP, Leave without Pay
- flsa: not used
- grade: An employee's level at NASA. 1 is the lowest 15 is highest for GS pay plan. SES pay plan are all listed as 0.
- hour_type: type of hour charged. REG is regular. SL is sick leave and more
- hour_type_group_name: hour type group, Base or Leave and more
- hours_charged: hours charged by employee for that day and hour type
- mseo: The Mission Support Enterprise Organization
- name: name of the employee
- org_assigned: the employee's Organization code the are assigned to. also known as org code.
- pay_basis: not used
- pay_period_end_date: the date the current pay period ended
- pay_period_start_date: the date the current pay period started
- pay_plan: the employee pay plan, GS is General Schedule, ST, SL, AD and ES all fall under SES.
- prm_flag: If Y the employee is a permanent employee, if N, they are Term employee
- remark: Comments added by employee for the pay period
- remote_worker_indicator: If Y, the employee is on a Remote agreement, if N, they are not.
- route_code: not used
- special_processing_flag: not used
- step: in the GS pay plan there are 10 steps. 1 is the lowest and 10 the highest. The higher the Step the higher the pay.
- telework_flag: Signifies if the hours charged can be classified as telework hours. Y is yes, N is no.
- wbs: Work break down structure code for where to charge the hours to.
- work_date: the work date in YYYY-MM-DD format
- work_schedule: type of work schedule the employee follows.
- wsc: work schedule code, Full Time, Part Time, and more.
