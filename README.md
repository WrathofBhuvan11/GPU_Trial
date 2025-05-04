# New_GPU
SIMD Based basic GPU Implementation 

gpu.sv

├── dcr.sv

├── controller.sv (for data memory)

├── controller.sv (for program memory)

├── dispatch.sv

└── compute_core.sv (multiple instances)

    ├── fetch.sv
    
    ├── decoder.sv
    
    ├── scheduler.sv
    
    ├── alu.sv (per thread)
    
    ├── load_store_unit.sv (per thread)
    
    ├── program_counter.sv
    
    └── registers.sv (per thread)
