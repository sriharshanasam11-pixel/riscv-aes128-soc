# Design and Verification of a Configurable AES-128 Encryption/Decryption Accelerator on a RISC-V VeeR EL2 SoC

## 1. Problem Statement
Embedded and Internet-of-Things (IoT) edge devices routinely handle sensitive data—including user credentials, cryptographic keys, sensor readings, and real-time operational telemetry—that must be safeguarded against interception, tampering, and unauthorized extraction in non-volatile storage and during wireless transmission. The Advanced Encryption Standard with a 128-bit key (AES-128, FIPS-197) is the global benchmark for symmetric encryption. However, executing AES-128 purely in software on a resource-constrained 32-bit RISC-V micro-controller incurs prohibitive performance and energy penalties. Software implementations burn hundreds to thousands of processor clock cycles per 16-byte block performing repetitive byte substitutions (S-box Look-Up Tables), byte permutations (ShiftRows), Galois Field matrix multiplications ($GF(2^8)$ MixColumns), and round-key scheduling. These CPU cycles are diverted from real-time sensing, edge analytics, and responsive networking.

Furthermore, software AES implementations on low-cost processors frequently suffer from software-induced timing side-channel vulnerabilities due to cache misses and data-dependent memory lookups. Because AES exhibits a strictly bounded, iterative round architecture (10 rounds for AES-128), it is ideally suited for hardware acceleration. Offloading cryptographic transformations to a dedicated hardware accelerator allows the processor to reclaim computational bandwidth, achieve deterministic execution latency, and significantly lower energy per encrypted byte.

The central engineering challenge is not simply the mathematical formulation of the cipher, but architecting and verifying a trustworthy, robust System-on-Chip (SoC) integration. A hardware accelerator must seamlessly interface with the processor core, bus interconnect, interrupt controller, and peripheral memory subsystem. Proving that the accelerator behaves correctly under nominal operation, high-throughput streaming, corner cases, and adversarial or invalid software configurations requires an exhaustive verification methodology. This project resolves these challenges by designing, integrating, and rigorously verifying an RTL-based SoC featuring a 32-bit RISC-V core, a custom memory-mapped AES-128 encryption/decryption accelerator, a hardware Pseudo-Random Number Generator (PRNG) for cryptographic initialization and salting, and a Serial Peripheral Interface (SPI) master controller for secure off-chip communication.

---

## 2. Proposed SoC Architecture
The SoC is structured around an open-standard 32-bit RISC-V core (RV32I/RV32IMC instruction set architecture with a 4-stage pipelined datapath). The core serves as the central orchestration engine and connects to the system through a high-performance, synchronous memory-mapped bus interconnect (Wishbone B4 / pipelined crossbar interface).

The SoC contains the following subsystems:
1. **RISC-V Central Processing Unit (RV32I/VeeR EL2 compatible)**: 32-bit Harvard/shared memory architecture, dual-port register file, integer arithmetic logic unit (ALU), branch evaluation unit, and bus master interface.
2. **Instruction Memory (ROM/SRAM)**: 16 KB dedicated program memory storing boot code, peripheral drivers, and security application routines.
3. **Data Memory (SRAM)**: 16 KB scratchpad RAM for application stacks, cryptographic buffers, and peripheral data structures.
4. **Synchronous Bus Interconnect & Address Decoder**: Central interconnect routing 32-bit addresses, data read/write channels, byte enables (`SEL[3:0]`), and handshake acknowledgment (`ACK_O`) with minimal arbitration latency.
5. **Universal Asynchronous Receiver/Transmitter (UART)**: Full-duplex serial communication peripheral with programmable 16-bit baud-rate divider, 8-N-1 framing, TX/RX buffers, and status interrupts for system telemetry and console debugging.
6. **32-Bit System Timer**: Real-time counter featuring a programmable 16-bit prescaler, 32-bit compare register, auto-reload capability, and interrupt generation for execution profiling.
7. **32-Bit General-Purpose Input/Output (GPIO)**: Bidirectional digital I/O port with software-configurable direction registers, direct pin read/write, set/clear registers, and interrupt-on-change support.
8. **AES-128 Encryption/Decryption Hardware Accelerator (Custom IP)**: Core cryptographic engine with 32-bit memory-mapped control, status, 128-bit key, and 128-bit input/output data registers. Implements SubBytes/InvSubBytes, ShiftRows/InvShiftRows, MixColumns/InvMixColumns, and AddRoundKey across an iterative 10-round datapath with on-the-fly key expansion.
9. **Pseudo-Random Number Generator (PRNG, Custom IP)**: Hardware 32-bit pseudo-random generator employing combined Galois Linear Feedback Shift Register (LFSR) and 32-bit Xorshift algorithms to generate dynamic session keys, nonces, and Initialization Vectors (IVs).
10. **Serial Peripheral Interface (SPI Master Controller, Integrated IP)**: Configurable serial engine supporting SPI Modes 0–3, programmable clock prescaling, automated chip-select management, and double-buffered transmit/receive FIFOs for streaming ciphertexts to off-chip flash memory or secure external transceivers.

Application software executing on the RISC-V core orchestrates secure operations: it initializes peripherals, samples session nonces from the PRNG, configures the AES key and input block via memory-mapped slave registers, triggers hardware encryption or decryption, polls the accelerator status or awaits interrupt completion, verifies cryptographic results, and streams the ciphertext off-chip through the SPI controller while logging performance telemetry via the UART.

---

## 3. Selected IP Blocks
In accordance with the project guidelines, three additional IP blocks are integrated into the mandatory SoC architecture:

1. **AES-128 Encryption/Decryption Accelerator (Custom IP)**:
   - *Role*: Dedicated symmetric cryptographic hardware accelerator.
   - *Functionality*: Performs NIST FIPS-197 compliant 128-bit AES encryption and decryption. Features memory-mapped 32-bit register access for keys (128 bits), plaintext/ciphertext inputs (128 bits), result outputs (128 bits), control (Start, Mode, Interrupt Enable), and status (Busy, Done, Error). Completes an encryption/decryption in 11 clock cycles with deterministic throughput.
2. **Pseudo-Random Number Generator (PRNG) (Custom IP)**:
   - *Role*: Hardware nonces and session salt generation.
   - *Functionality*: 32-bit hybrid Galois LFSR and Xorshift generator providing non-repeating dynamic sequences. Enables cryptographic protocols (e.g., CBC/CTR mode IV generation and key salting) without consuming processor arithmetic cycles.
3. **SPI Master Controller (Reused/Modified IP)**:
   - *Role*: High-speed synchronous serial interface to off-chip storage and peripherals.
   - *Functionality*: Provides full-duplex synchronous transfers with programmable clock division, software chip select (`CS_N`), and status flags. Allows rapid serialization of encrypted blocks to external SPI flash or companion IoT radios.

---

## 4. Verification Plan
Verification follows a rigorous bottom-up methodology spanning unit-level, sub-system, and full-chip SoC integration:
- **Unit-Level Hardware Verification**:
  - *AES-128 Accelerator*: Verified against NIST SP 800-38A and FIPS-197 Known Answer Test (KAT) vectors (e.g., Key: `000102030405060708090a0b0c0d0e0f`, Plaintext: `00112233445566778899aabbccddeeff` $\rightarrow$ Ciphertext: `69c4e0d86a7b0430d8cdb78070b4c55a`, followed by full round-trip decryption to verify exact plaintext restoration).
  - *PRNG & SPI*: Verified via directed and pseudo-random seed testbenches, checking period lengths, polynomial feedback, SPI clock phase/polarity modes, and FIFO overflow/underflow handling.
- **SystemVerilog Assertions (SVA)**: Formal protocol checkers ensure no bus hanging occurs (`ACK_O` asserted within maximum timeout), illegal register accesses trigger fault flags, and start-busy-done handshakes in the accelerator maintain strict temporal consistency.
- **Full SoC Integration & Software Co-Verification**:
  - The RISC-V processor executes an embedded C/assembly application that configures all peripherals, generates dynamic random salts, benchmarks cycle latency for AES acceleration against software baselines, and logs execution telemetry over UART.
  - Cycle-accurate simulation and self-checking testbenches assert 100% test pass on NIST test vectors, memory integrity, and bus protocol compliance.
