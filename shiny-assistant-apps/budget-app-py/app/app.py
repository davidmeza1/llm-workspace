from shiny import App, ui, render, reactive
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Sample data generation for overview
def generate_sample_overview():
    months = ['October', 'November', 'December', 'January', 'February', 
              'March', 'April', 'May', 'June', 'July', 'August', 'September']
    
    # Using the total values from AWS data as planned
    planned = [950.92, 851.79, 0, 315.57, 442.52, 
              658.69, 770.96, 1046.69, 1095.92, 1084.15, 1114.80, 1152.05]
    
    # Generate actual values with some random variation
    np.random.seed(123)
    actual = [p + np.random.normal(0, p * 0.05) if p > 0 else 0 for p in planned]
    
    return pd.DataFrame({
        'Month': months,
        'Planned': planned,
        'Actual': actual
    })

# Sample data generation for detailed view
def generate_sample_detailed():
    months = ['October', 'November', 'December', 'January', 'February', 
              'March', 'April', 'May', 'June', 'July', 'August', 'September']
    
    # Using AWS services as items
    items = ['AmazonEC2', 'AWSELB', 'AmazonVPC', 'AmazonRDS', 'AWSConfig',
             'AmazonGuardDuty', 'AmazonInspectorV2', 'AWSMarketplace', 'AWSSecurityHub', 'AmazonCloudWatch']
    
    data = []
    np.random.seed(123)
    
    for item in items:
        base_value = np.random.uniform(100, 1000)
        for month in months:
            planned = base_value + np.random.normal(0, base_value * 0.1)
            actual = planned + np.random.normal(0, planned * 0.05)
            data.append({
                'Month': month,
                'Item': item,
                'Planned': planned,
                'Actual': actual
            })
    
    return pd.DataFrame(data)

# Initialize sample data
overview_data = generate_sample_overview()
detailed_data = generate_sample_detailed()

app_ui = ui.page_fluid(
    ui.navset_tab(
        ui.nav_panel("Overview",
            ui.layout_columns(
                ui.input_file("overview_file", "Upload Overview Budget Excel File",
                            accept=[".xlsx", ".xls"]),
                width=1/3
            ),
            ui.layout_columns(
                ui.value_box(
                    "Total Planned Budget",
                    ui.output_text("total_planned"),
                    theme="primary"
                ),
                ui.value_box(
                    "Total Actual Spent",
                    ui.output_text("total_actual"),
                    theme="secondary"
                ),
                ui.value_box(
                    "Variance",
                    ui.output_text("variance"),
                    theme="warning"
                ),
                ui.value_box(
                    "% of Budget Used",
                    ui.output_text("budget_used"),
                    theme="success"
                ),
            ),
            ui.card(
                ui.card_header("Budget Comparison"),
                ui.output_plot("overview_plot")
            ),
        ),
        ui.nav_panel("Detailed Items",
            ui.layout_columns(
                ui.input_file("detailed_file", "Upload Detailed Budget Excel File",
                            accept=[".xlsx", ".xls"]),
                width=1/3
            ),
            ui.layout_columns(
                ui.value_box(
                    "Number of Items",
                    ui.output_text("item_count"),
                    theme="primary"
                ),
                ui.value_box(
                    "Highest Budget Item",
                    ui.output_text("highest_item"),
                    theme="secondary"
                ),
                ui.value_box(
                    "Total Variance",
                    ui.output_text("detailed_variance"),
                    theme="warning"
                ),
                ui.value_box(
                    "Average Budget Usage",
                    ui.output_text("avg_budget_used"),
                    theme="success"
                ),
            ),
            ui.card(
                ui.card_header("Item Selection"),
                ui.layout_columns(
                    ui.input_select("selected_item", "Select Budget Item", 
                                  choices=list(detailed_data['Item'].unique())),
                    ui.input_select("selected_month", "Select Month", 
                                  choices=['All'] + list(detailed_data['Month'].unique())),
                    width=1/2
                )
            ),
            ui.card(
                ui.card_header("Detailed Budget Comparison"),
                ui.output_plot("detailed_plot")
            ),
        )
    )
)

def server(input, output, session):
    # Reactive values for data
    overview_df = reactive.value(overview_data)
    detailed_df = reactive.value(detailed_data)
    
    @reactive.effect
    def _():
        if input.overview_file():
            file_path = input.overview_file()[0]["datapath"]
            data = pd.read_excel(file_path)
            overview_df.set(data)

    @reactive.effect
    def _():
        if input.detailed_file():
            file_path = input.detailed_file()[0]["datapath"]
            data = pd.read_excel(file_path)
            detailed_df.set(data)
            # Update item choices
            updateSelectInput("selected_item", choices=list(data['Item'].unique()))
    
    # Overview tab outputs
    @output
    @render.text
    def total_planned():
        return f"${overview_df().Planned.sum():,.2f}"

    @output
    @render.text
    def total_actual():
        return f"${overview_df().Actual.sum():,.2f}"

    @output
    @render.text
    def variance():
        variance = overview_df().Planned.sum() - overview_df().Actual.sum()
        return f"${variance:,.2f}"

    @output
    @render.text
    def budget_used():
        percentage = (overview_df().Actual.sum() / overview_df().Planned.sum()) * 100
        return f"{percentage:.1f}%"

    @output
    @render.plot
    def overview_plot():
        plt.figure(figsize=(10, 6))
        months = overview_df()['Month']
        plt.plot(months, overview_df()['Planned'], 'b-', linewidth=2, label='Planned')
        plt.plot(months, overview_df()['Actual'], 'r-', linewidth=2, label='Actual')
        plt.xticks(rotation=45)
        plt.title('Budget Overview: Planned vs Actual')
        plt.xlabel('Month')
        plt.ylabel('Amount ($)')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()

    # Detailed tab outputs
    @output
    @render.text
    def item_count():
        return str(len(detailed_df()['Item'].unique()))

    @output
    @render.text
    def highest_item():
        grouped = detailed_df().groupby('Item')['Planned'].sum()
        return grouped.idxmax()

    @output
    @render.text
    def detailed_variance():
        variance = detailed_df()['Planned'].sum() - detailed_df()['Actual'].sum()
        return f"${variance:,.2f}"

    @output
    @render.text
    def avg_budget_used():
        percentage = (detailed_df()['Actual'].sum() / detailed_df()['Planned'].sum()) * 100
        return f"{percentage:.1f}%"

    @output
    @render.plot
    def detailed_plot():
        filtered_data = detailed_df()
        if input.selected_item():
            filtered_data = filtered_data[filtered_data['Item'] == input.selected_item()]
        
        if input.selected_month() != 'All':
            filtered_data = filtered_data[filtered_data['Month'] == input.selected_month()]

        plt.figure(figsize=(10, 6))
        if input.selected_month() == 'All':
            months = filtered_data['Month']
            plt.plot(months, filtered_data['Planned'], 'b-', linewidth=2, label='Planned')
            plt.plot(months, filtered_data['Actual'], 'r-', linewidth=2, label='Actual')
        else:
            plt.bar(['Planned', 'Actual'], 
                   [filtered_data['Planned'].iloc[0], filtered_data['Actual'].iloc[0]],
                   color=['blue', 'red'])
            
        plt.xticks(rotation=45)
        plt.title(f'Budget Details for {input.selected_item()}')
        plt.xlabel('Month' if input.selected_month() == 'All' else 'Type')
        plt.ylabel('Amount ($)')
        if input.selected_month() == 'All':
            plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()

app = App(app_ui, server)
