# ARM-LEGv8-CPU
This is a Verilog implementation of an ARMv8 CPU with the LEGv8 subset of instructions.\
Implementation found in `cpu5arm.v`, test bench found in `cpu5armtb.v`.

## CPU Schematic

![CPU Schematic](cpuschematic.png)

## Instructions
| Instruction   | Opcode      |
| ------------- | ----------- |
| ADD           | 00101000000 |
| ADDS          | 00101000001 |
| AND           | 00101000010 |
| ANDS          | 00101000011 |
| EOR           | 00101000100 |
| ENOR          | 00101000101 |
| LSL           | 00101000110 |
| LSR           | 00101000111 |
| ORR           | 00101001000 |
| SUB           | 00101001001 |
| SUBS          | 00101001010 |
| ADDI          | 1000100000  |
| ADDIS         | 1000100001  |
| ANDI          | 1000100010  |
| ANDIS         | 1000100011  |
| EORI          | 1000100100  |
| ENORI         | 1000100101  |
| ORRI          | 1000100110  |
| SUBI          | 1000100111  |
| SUBIS         | 1000101000  |
| LDUR          | 11010000000 |
| STUR          | 11010000001 |
| MOVZ          | 110010101   |
| B             | 000011      |
| CBZ           | 11110100    |
| CBNZ          | 11110101    |
| B.EQ          | 01110100    |
| B.NE          | 01110101    |
| B.LT (Signed) | 01110110    |
| B.GE (Signed) | 01110111    |
