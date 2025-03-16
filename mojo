from python import Python
from collections.vector import DynamicVector
from utils.static_tuple import StaticTuple
from utils.index import Index
from memory import memset_zero

struct TaxRecord:
    var state: String
    var state_tax_rate: Float64
    var avg_local_tax_rate: Float64
    var combined_rate: Float64
    var max_local_rate: Float64
    var state_rank: Int
    var combined_rank: Int
    
    fn __init__(inout self, 
                state: String, 
                state_tax_rate: Float64, 
                avg_local_tax_rate: Float64,
                combined_rate: Float64, 
                max_local_rate: Float64,
                state_rank: Int,
                combined_rank: Int):
        self.state = state
        self.state_tax_rate = state_tax_rate
        self.avg_local_tax_rate = avg_local_tax_rate
        self.combined_rate = combined_rate
        self.max_local_rate = max_local_rate
        self.state_rank = state_rank
        self.combined_rank = combined_rank
    
    fn __str__(self) -> String:
        return self.state + ": State Tax=" + String(self.state_tax_rate) + "%, Combined=" + String(self.combined_rate) + "%"


fn parse_csv_file(filename: String) raises -> DynamicVector[TaxRecord]:
    """Parse the CSV file and extract tax data for all states."""
    # Use Python's CSV module for parsing
    let py = Python.import_module("builtins")
    let os = Python.import_module("os")
    let csv = Python.import_module("csv")
    
    var tax_records = DynamicVector[TaxRecord]()
    
    # Check if file exists
    if not os.path.exists(filename):
        print("Error: File", filename, "not found")
        return tax_records
    
    # Open and read the CSV file
    with open(filename, "r") as file:
        let csv_reader = csv.reader(file)
        
        # Skip the header row
        let _ = next(csv_reader)
        
        # Process each row
        for row in csv_reader:
            if len(row) >= 7:
                let state = String(row[0])
                
                # Parse rates, removing % signs
                let state_tax_rate = Float64(row[1].replace("%", ""))
                let avg_local_tax_rate = Float64(row[3].replace("%", ""))
                let combined_rate = Float64(row[4].replace("%", ""))
                let max_local_rate = Float64(row[6].replace("%", ""))
                
                # Parse ranks
                let state_rank = Int(row[2])
                let combined_rank = Int(row[5])
                
                let record = TaxRecord(
                    state, 
                    state_tax_rate, 
                    avg_local_tax_rate, 
                    combined_rate, 
                    max_local_rate,
                    state_rank,
                    combined_rank
                )
                
                _ = tax_records.push_back(record)
    
    return tax_records


fn find_state_record(records: DynamicVector[TaxRecord], state_name: String) -> TaxRecord:
    """Find a state's tax record by name."""
    var empty_record = TaxRecord("Not Found", 0.0, 0.0, 0.0, 0.0, 0, 0)
    
    for i in range(len(records)):
        if records[i].state == state_name:
            return records[i]
    
    return empty_record


fn compare_tax_rates(state1: TaxRecord, state2: TaxRecord):
    """Print a comparison of tax rates between two states."""
    print("Tax Rate Comparison:", state1.state, "vs", state2.state, "(2024)")
    print("=" * 60)
    
    print("\nState Tax Rates:")
    print(f"  {state1.state}: {state1.state_tax_rate}% (Rank #{state1.state_rank})")
    print(f"  {state2.state}: {state2.state_tax_rate}% (Rank #{state2.state_rank})")
    print(f"  Difference: {state1.state_tax_rate - state2.state_tax_rate}%")
    
    print("\nAverage Local Tax Rates:")
    print(f"  {state1.state}: {state1.avg_local_tax_rate}%")
    print(f"  {state2.state}: {state2.avg_local_tax_rate}%")
    print(f"  Difference: {state1.avg_local_tax_rate - state2.avg_local_tax_rate}%")
    
    print("\nCombined Tax Rates:")
    print(f"  {state1.state}: {state1.combined_rate}% (Rank #{state1.combined_rank})")
    print(f"  {state2.state}: {state2.combined_rate}% (Rank #{state2.combined_rank})")
    print(f"  Difference: {state1.combined_rate - state2.combined_rate}%")
    
    print("\nMaximum Local Tax Rates:")
    print(f"  {state1.state}: {state1.max_local_rate}%")
    print(f"  {state2.state}: {state2.max_local_rate}%")
    print(f"  Difference: {state1.max_local_rate - state2.max_local_rate}%")
    

fn plot_comparison(tn_data: TaxRecord, nc_data: TaxRecord):
    """Generate a simple ASCII plot comparing the tax rates."""
    let max_value = max(tn_data.combined_rate, nc_data.combined_rate)
    let scale = 40.0 / max_value  # Scale for a 40-character wide bar
    
    print("\nVisual Comparison (ASCII Chart):")
    print("=" * 60)
    
    # State tax rate bars
    print("\nState Tax Rate:")
    print(f"{tn_data.state:15} | {'█' * Int(tn_data.state_tax_rate * scale)} {tn_data.state_tax_rate}%")
    print(f"{nc_data.state:15} | {'█' * Int(nc_data.state_tax_rate * scale)} {nc_data.state_tax_rate}%")
    
    # Local tax rate bars
    print("\nLocal Tax Rate:")
    print(f"{tn_data.state:15} | {'█' * Int(tn_data.avg_local_tax_rate * scale)} {tn_data.avg_local_tax_rate}%")
    print(f"{nc_data.state:15} | {'█' * Int(nc_data.avg_local_tax_rate * scale)} {nc_data.avg_local_tax_rate}%")
    
    # Combined tax rate bars
    print("\nCombined Tax Rate:")
    print(f"{tn_data.state:15} | {'█' * Int(tn_data.combined_rate * scale)} {tn_data.combined_rate}%")
    print(f"{nc_data.state:15} | {'█' * Int(nc_data.combined_rate * scale)} {nc_data.combined_rate}%")


fn main() raises:
    let filename = "2024 Sales Tax Rates State  Local Sales Tax by State.csv"
    
    print("Loading tax data from:", filename)
    let tax_records = parse_csv_file(filename)
    print("Loaded", len(tax_records), "state tax records")
    
    let tn_data = find_state_record(tax_records, "Tennessee")
    let nc_data = find_state_record(tax_records, "North Carolina")
    
    if tn_data.state == "Not Found" or nc_data.state == "Not Found":
        print("Error: Could not find data for one or both states")
        return
    
    # Print detailed comparison
    compare_tax_rates(tn_data, nc_data)
    
    # Generate simple ASCII chart
    plot_comparison(tn_data, nc_data)
    
    # Summary
    print("\nSummary:")
    print("=" * 60)
    print(f"{tn_data.state} has a {tn_data.combined_rate - nc_data.combined_rate}% higher combined tax rate than {nc_data.state}")
    print(f"{tn_data.state} ranks #{tn_data.combined_rank} nationally in combined tax rate")
    print(f"{nc_data.state} ranks #{nc_data.combined_rank} nationally in combined tax rate")


# Run the main function
if __name__ == "__main__":
    try:
        main()
    except:
        print("An error occurred while processing the tax data")