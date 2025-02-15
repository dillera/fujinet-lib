# Atari SIO Bus Implementation

This directory contains the implementation of the Atari Serial Input/Output (SIO) bus interface for the FujiNet library. The SIO bus is the primary means of communication between the Atari computer and its peripheral devices.

## Key Components

### SIO Interrupt Handler (`sio_interrupt.s`)

The interrupt handler manages asynchronous serial communication with devices on the SIO bus. It uses the Atari OS's built-in interrupt vectors and hardware registers to efficiently handle serial data transfer.

#### Core Components:

1. **Interrupt Vector Management**
   - Uses `VSERIR` ($0206) - Serial Input Ready vector
   - Saves and restores original vector state
   - Properly masks interrupts during critical operations

2. **Buffer Management**
   - 256-byte circular receive buffer
   - Tracks buffer length and current index
   - Prevents buffer overflow

3. **Data Transfer**
   - Reads data from `SERIN` register
   - Copies data to target buffer when requested
   - Tracks remaining bytes for current operation

#### Key Functions:

- `_sio_init_interrupts`: Initializes the interrupt system
  - Saves existing vector state
  - Sets up interrupt handler
  - Enables serial I/O interrupts
  - Initializes buffer management

- `_sio_disable_interrupts`: Cleans up interrupt system
  - Restores original vectors
  - Restores original interrupt mask state
  - Ensures system integrity

- `_sio_interrupt_handler`: Main interrupt service routine
  - Handles incoming serial data
  - Re-enables interrupts after acknowledgment
  - Manages buffer operations
  - Updates transfer status

#### Important Hardware Registers:

- `VSERIR` ($0206): Serial Input Ready vector
- `POKMSK`: Interrupt mask register
- `IRQEN`: Interrupt enable register
- `SERIN`: Serial input register

## Implementation Details

### Interrupt Flow:

1. **Initialization**
   ```assembly
   sei                  ; Disable interrupts
   [Save vectors]       ; Store original system state
   [Setup vectors]      ; Point to our handler
   [Enable interrupts]  ; Configure interrupt masks
   cli                  ; Re-enable interrupts
   ```

2. **Interrupt Handling**
   ```assembly
   [Save registers]     ; Preserve CPU state
   [Check interrupt]    ; Verify it's our interrupt
   [Re-enable int]      ; Re-enable after acknowledgment
   [Process data]       ; Handle incoming byte
   [Restore state]      ; Restore CPU state
   ```

3. **Cleanup**
   ```assembly
   sei                  ; Disable interrupts
   [Restore vectors]    ; Return to original state
   [Restore masks]      ; Reset interrupt configuration
   cli                  ; Re-enable interrupts
   ```

### Buffer Management:

The system uses a 256-byte circular buffer to handle incoming data. This allows for:
- Efficient interrupt handling (quick storage of incoming bytes)
- Decoupling of data reception from processing
- Prevention of data loss due to timing issues

## Usage Notes

1. Always initialize the system with `_sio_init_interrupts` before use
2. Monitor `_sio_read_complete` flag for transfer status
3. Use `_sio_disable_interrupts` when done to restore system state
4. Be aware that interrupts are briefly disabled during vector manipulation

## Important Considerations

1. **Interrupt Re-enabling**: The Atari OS disables the interrupt as acknowledgment. The handler must re-enable it after each interrupt.
2. **Vector Safety**: The system saves and restores vectors to maintain system integrity.
3. **Buffer Limitations**: The 256-byte buffer size means you must process data before buffer overflow occurs.
4. **Timing**: Interrupt handling is time-critical - keep the handler routine as efficient as possible.
