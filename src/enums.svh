// Enum from fetch
typedef enum logic [1:0] {
    FETCH_IDLE,
    FETCH_REQUEST,
    FETCH_WAIT_READY
} fetch_state_t;

// Enum from load_store_unit
typedef enum logic [1:0] {
    LSU_IDLE,
    LSU_LOAD,
    LSU_STORE
} lsu_state_t;

// Enum from compute_core
typedef enum logic [2:0] {
    IDLE,
    FETCH,
    DECODE,
    EXECUTE,
    WRITEBACK,
    HALT
} core_state_t;
