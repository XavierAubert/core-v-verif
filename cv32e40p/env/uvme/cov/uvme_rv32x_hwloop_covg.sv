///////////////////////////////////////////////////////////////////////////////
// Copyright 2020 OpenHW Group
// Copyright 2023 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
///////////////////////////////////////////////////////////////////////////////

// Note: 
// 1) This coverage model complements Imperas coverage XPULPV2 with addtional coverage collection related to hwloops
// 2) It uses uvmt_cv32e40p_rvvi_if
// 3) Has covergroup for hwloops csr setup registers
// 4) Has covergroup for hwloops features and events within hwloops such as exception, irq and debug entry (debug covers haltreq, trigger, ebreakm, step)

`ifndef UVME_RV32X_HWLOOP_COVG
`define UVME_RV32X_HWLOOP_COVG

class uvme_rv32x_hwloop_covg # (
  parameter int ILEN    = 32,
  parameter int XLEN    = 32
) extends uvm_component;

  localparam SKIP_RVVI_INIT_VALID_CNT = 1;
  localparam HWLOOP_NB = 2;
  localparam CSR_LPSTART0_ADDR = 32'hCC0;
  localparam CSR_LPEND0_ADDR   = 32'hCC1;
  localparam CSR_LPCOUNT0_ADDR = 32'hCC2;
  localparam INSN_CEBREAK      = 32'h00009002; // compress ebreak
  localparam INSN_ILLEGAL      = 32'hFFFFFFFF; // user-defined for any illegal insn that leads to illegal exception
  localparam INSN_EBREAKM      = 32'hFFFFFFFE; // user-defined

  typedef enum bit [1:0] {NULL_TYPE=0, SINGLE, NESTED}  hwloop_type_t;
  typedef enum bit [1:0] {NULL_SETUP=0, SHORT, LONG}    hwloop_setup_t;
  typedef struct {
    bit [31:0] lp_start     [HWLOOP_NB];
    bit [31:0] lp_end       [HWLOOP_NB];
    bit [31:0] lp_count     [HWLOOP_NB];
    bit        lp_start_wb  [HWLOOP_NB];
    bit        lp_end_wb    [HWLOOP_NB];
    bit        lp_count_wb  [HWLOOP_NB];
  } s_csr_hwloop;
  typedef struct {
    hwloop_type_t     hwloop_type;
    hwloop_setup_t    hwloop_setup [HWLOOP_NB];
    s_csr_hwloop      hwloop_csr;
    bit               execute_instr_in_hwloop [HWLOOP_NB];
    int               track_lp_count [HWLOOP_NB];
  } s_hwloop_stat;

  // PROPERTIES - START
  local s_csr_hwloop  csr_hwloop_init   = '{default:0};
  local s_hwloop_stat hwloop_stat_init  = '{default:0, hwloop_type:NULL_TYPE, hwloop_setup:'{default:NULL_SETUP}};

  `define DEF_LOCAL_VARS(TYPE) \
  local s_csr_hwloop        csr_hwloop_``TYPE   = '{default:0}; \
  local s_hwloop_stat       hwloop_stat_``TYPE  = '{default:0, hwloop_type:NULL_TYPE, hwloop_setup:'{default:NULL_SETUP}}; \
  local bit [(ILEN-1):0]    insn_list_in_hwloop_``TYPE      [HWLOOP_NB][$]; \
  local bit [31:0]          irq_vect_``TYPE                 [HWLOOP_NB][$]; \
  local bit                 dbg_mode_``TYPE                 [HWLOOP_NB] = '{default:0}; \
  local int unsigned        dbg_step_cnt_``TYPE             [HWLOOP_NB] = '{default:0}; \
  local bit                 done_insn_list_capture_``TYPE   [HWLOOP_NB] = '{default:0};
  
  `DEF_LOCAL_VARS(main)
  `DEF_LOCAL_VARS(sub)

  virtual uvmt_cv32e40p_rvvi_if #( .XLEN(XLEN), .ILEN(ILEN)) cv32e40p_rvvi_vif;
  string  _header = "XPULPV2_HWLOOP_COV";
  bit     en_cvg_sampling = 1;
  bit     in_nested_loop0 = 0;
  bit     is_ebreak = 0, is_ebreakm, is_ecall = 0, is_illegal = 0, is_irq = 0, is_dbg_mode = 0, is_dbg_trigger = 0;
  bit     enter_hwloop_sub = 0;

  // PROPERTIES - END

  // COVERGROUPS DEFINE HERE - START

  `define CG_CSR_HWLOOP(LOOP_IDX) cg_csr_hwloop_``LOOP_IDX``
  `define DEF_CG_CSR_HWLOOP(LOOP_IDX) covergroup cg_csr_hwloop_``LOOP_IDX with function sample(s_csr_hwloop csr_hwloop); \
    option.per_instance         = 1; \
    `ifdef MODEL_TECH \
    option.get_inst_coverage    = 1; \
    `endif \
    type_option.merge_instances = 1; \
    cp_lpstart_``LOOP_IDX : coverpoint (csr_hwloop.lp_start[``LOOP_IDX``]) iff (csr_hwloop.lp_start_wb[``LOOP_IDX``] && csr_hwloop.lp_end_wb[``LOOP_IDX``] && csr_hwloop.lp_count_wb[``LOOP_IDX``]) { \
      bins lpstart_range_0      = {[32'h0000_03FC : 32'h0000_0004]}; \
      bins lpstart_range_1      = {[32'h0000_0FFC : 32'h0000_0400]}; \
      bins lpstart_range_2      = {[32'h0000_FFFC : 32'h0000_1000]}; \
      // higher range is not covered now due to limited generated codespace (amend if needed) \
    } \
    cp_lpend_``LOOP_IDX : coverpoint (csr_hwloop.lp_end[``LOOP_IDX``]) iff (csr_hwloop.lp_start_wb[``LOOP_IDX``] && csr_hwloop.lp_end_wb[``LOOP_IDX``] && csr_hwloop.lp_count_wb[``LOOP_IDX``]) { \
      bins lpend_range_0        = {[32'h0000_03FC : 32'h0000_0004]}; \
      bins lpend_range_1        = {[32'h0000_0FFC : 32'h0000_0400]}; \
      bins lpend_range_2        = {[32'h0000_FFFC : 32'h0000_1000]}; \
      // higher range is not covered now due to limited generated codespace (amend if needed) \
    } \
    cp_lpcount_``LOOP_IDX : coverpoint (csr_hwloop.lp_count[``LOOP_IDX``]) iff (csr_hwloop.lp_start_wb[``LOOP_IDX``] && csr_hwloop.lp_end_wb[``LOOP_IDX``] && csr_hwloop.lp_count_wb[``LOOP_IDX``]) { \
      // bins lpcount_zero           = {32'h0}; // valid CSR writes to sample should be when lpcount{0/1}.value != 0 \
      bins lpcount_range_low_1    = {[32'h0000_00FF : 32'h0000_0001]}; // 1 <= x <255 \
      bins lpcount_range_low_2    = {[32'h0000_1FFF : 32'h0000_0100]}; // 256 <= x < 4K \
      // bins lpcount_range_middle   = {[32'h00FF_FFFF : 32'h0000_1000]}; // 4K <= x < 16M \
      // bins lpcount_range_high     = {[32'hFFFF_FFFF : 32'h0100_0000]}; // 16M <= x < 4G \
      // commented higher counts are not covered now to reduced simtime (amend if needed) \
    } \
    ccp_lpstart_0_lpend_lpcount_``LOOP_IDX : cross cp_lpstart_``LOOP_IDX``, cp_lpend_``LOOP_IDX``, cp_lpcount_``LOOP_IDX`` { \
      ignore_bins ignore__lpstart_range_1 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_0FFC : 32'h0000_0400]}; \
      ignore_bins ignore__lpstart_range_2 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_FFFC : 32'h0000_1000]}; \
    } \
    ccp_lpstart_1_lpend_lpcount_``LOOP_IDX : cross cp_lpstart_``LOOP_IDX``, cp_lpend_``LOOP_IDX``, cp_lpcount_``LOOP_IDX`` { \
      ignore_bins ignore__lpstart_range_0 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_03FC : 32'h0000_0004]}; \
      ignore_bins ignore__lpstart_range_2 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_FFFC : 32'h0000_1000]}; \
      ignore_bins ignore__lpend_range_0   = binsof (cp_lpend_``LOOP_IDX``)   intersect {[32'h0000_03FC : 32'h0000_0004]}; \
    } \
    ccp_lpstart_2_lpend_lpcount_``LOOP_IDX : cross cp_lpstart_``LOOP_IDX``, cp_lpend_``LOOP_IDX``, cp_lpcount_``LOOP_IDX`` { \
      ignore_bins ignore__lpstart_range_0 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_03FC : 32'h0000_0004]}; \
      ignore_bins ignore__lpstart_range_1 = binsof (cp_lpstart_``LOOP_IDX``) intersect {[32'h0000_0FFC : 32'h0000_0400]}; \
      ignore_bins ignore__lpend_range_0   = binsof (cp_lpend_``LOOP_IDX``)   intersect {[32'h0000_03FC : 32'h0000_0004]}; \
      ignore_bins ignore__lpend_range_1   = binsof (cp_lpend_``LOOP_IDX``)   intersect {[32'h0000_0FFC : 32'h0000_0400]}; \
    } \
  endgroup : cg_csr_hwloop_``LOOP_IDX

  `define CG_FEATURES_OF_HWLOOP(LOOP_IDX) cg_features_of_hwloop_``LOOP_IDX``
  `define DEF_CG_FEATURES_OF_HWLOOP(LOOP_IDX) covergroup cg_features_of_hwloop_``LOOP_IDX with function \
    sample(s_hwloop_stat hwloop_stat, bit [31:0] insn, bit [31:0] irq, bit dbg_mode, int unsigned dbg_step_cnt); \
    option.per_instance         = 1; \
    `ifdef MODEL_TECH \
    option.get_inst_coverage    = 1; \
    `endif \
    type_option.merge_instances = 1; \
    cp_hwloop_type : coverpoint (hwloop_stat.hwloop_type) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins single_hwloop      = {SINGLE}; \
      bins nested_hwloop      = {NESTED}; \
      illegal_bins invalid    = default; \
    } \
    cp_hwloop_setup : coverpoint (hwloop_stat.hwloop_setup[``LOOP_IDX``]) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins short_hwloop_setup = {SHORT}; \
      bins long_hwloop_setup  = {LONG}; \
      illegal_bins invalid    = default; \
    } \
    cp_hwloop_irq : coverpoint (irq) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins vec_irq[]          = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'h0000_0008, \
                                 32'h0000_0010, 32'h0000_0020, 32'h0000_0040, 32'h0000_0080, \
                                 32'h0000_0100, 32'h0000_0200, 32'h0000_0400, 32'h0000_0800, \
                                 32'h0000_1000, 32'h0000_2000, 32'h0000_4000, 32'h0000_8000, \
                                 32'h0001_0000, 32'h0002_0000, 32'h0004_0000, 32'h0008_0000, \
                                 32'h0010_0000, 32'h0020_0000, 32'h0040_0000, 32'h0080_0000, \
                                 32'h0100_0000, 32'h0200_0000, 32'h0400_0000, 32'h0800_0000, \
                                 32'h1000_0000, 32'h2000_0000, 32'h4000_0000, 32'h8000_0000}; \
    } \
    cp_hwloop_dbg_mode : coverpoint (dbg_mode) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins dbg_mode             = {1}; \
    } \
    cp_hwloop_dbg_step_cnt : coverpoint (dbg_step_cnt) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins dbg_step_cnt[]       = {[5:15]}; /* todo: determine the cnt range that exercise in tests */ \
    } \
    // refer to cv32e40p_tracer_pkg.sv for instructions list \
    // note: hwloop setup custom instructions are not allow in hwloop_0 (manual exclusion needed) \
    cp_insn_list_in_hwloop : coverpoint (insn) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      wildcard bins instr_lui = {INSTR_LUI}; \
      wildcard bins instr_auipc = {INSTR_AUIPC}; \
      // OPIMM \
      wildcard bins instr_addi = {INSTR_ADDI}; \
      wildcard bins instr_slti = {INSTR_SLTI}; \
      wildcard bins instr_sltiu = {INSTR_SLTIU}; \
      wildcard bins instr_xori = {INSTR_XORI}; \
      wildcard bins instr_ori = {INSTR_ORI}; \
      wildcard bins instr_andi = {INSTR_ANDI}; \
      wildcard bins instr_slli = {INSTR_SLLI}; \
      wildcard bins instr_srli = {INSTR_SRLI}; \
      wildcard bins instr_srai = {INSTR_SRAI}; \
      // OP \
      wildcard bins instr_add = {INSTR_ADD}; \
      wildcard bins instr_sub = {INSTR_SUB}; \
      wildcard bins instr_sll = {INSTR_SLL}; \
      wildcard bins instr_slt = {INSTR_SLT}; \
      wildcard bins instr_sltu = {INSTR_SLTU}; \
      wildcard bins instr_xor = {INSTR_XOR}; \
      wildcard bins instr_srl = {INSTR_SRL}; \
      wildcard bins instr_sra = {INSTR_SRA}; \
      wildcard bins instr_or = {INSTR_OR}; \
      wildcard bins instr_and = {INSTR_AND}; \
      wildcard bins instr_pavg = {INSTR_PAVG}; \
      wildcard bins instr_pavgu = {INSTR_PAVGU}; \
      // SYSTEM \
      wildcard bins instr_csrrw = {INSTR_CSRRW}; \
      wildcard bins instr_csrrs = {INSTR_CSRRS}; \
      wildcard bins instr_csrrc = {INSTR_CSRRC}; \
      wildcard bins instr_csrrwi = {INSTR_CSRRWI}; \
      wildcard bins instr_csrrsi = {INSTR_CSRRSI}; \
      wildcard bins instr_csrrci = {INSTR_CSRRCI}; \
      wildcard bins instr_ecall = {INSTR_ECALL}; \
      wildcard bins instr_ebreak = {INSTR_EBREAK}; \
      // RV32M \
      wildcard bins instr_div = {INSTR_DIV}; \
      wildcard bins instr_divu = {INSTR_DIVU}; \
      wildcard bins instr_rem = {INSTR_REM}; \
      wildcard bins instr_remu = {INSTR_REMU}; \
      wildcard bins instr_pmul = {INSTR_PMUL}; \
      wildcard bins instr_pmuh = {INSTR_PMUH}; \
      wildcard bins instr_pmulhsu = {INSTR_PMULHSU}; \
      wildcard bins instr_pmulhu = {INSTR_PMULHU}; \
      // RV32F \
      wildcard bins instr_fmadd = {INSTR_FMADD}; \
      wildcard bins instr_fmsub = {INSTR_FMSUB}; \
      wildcard bins instr_fnmsub = {INSTR_FNMSUB}; \
      wildcard bins instr_fnmadd = {INSTR_FNMADD}; \
      wildcard bins instr_fadd = {INSTR_FADD}; \
      wildcard bins instr_fsub = {INSTR_FSUB}; \
      wildcard bins instr_fmul = {INSTR_FMUL}; \
      wildcard bins instr_fdiv = {INSTR_FDIV}; \
      wildcard bins instr_fsqrt = {INSTR_FSQRT}; \
      wildcard bins instr_fsgnjs = {INSTR_FSGNJS}; \
      wildcard bins instr_fsgnjns = {INSTR_FSGNJNS}; \
      wildcard bins instr_fsgnjxs = {INSTR_FSGNJXS}; \
      wildcard bins instr_fmin = {INSTR_FMIN}; \
      wildcard bins instr_fmax = {INSTR_FMAX}; \
      wildcard bins instr_fcvtws = {INSTR_FCVTWS}; \
      wildcard bins instr_fcvtwus = {INSTR_FCVTWUS}; \
      wildcard bins instr_fmvxs = {INSTR_FMVXS}; \
      wildcard bins instr_feqs = {INSTR_FEQS}; \
      wildcard bins instr_flts = {INSTR_FLTS}; \
      wildcard bins instr_fles = {INSTR_FLES}; \
      wildcard bins instr_fclass = {INSTR_FCLASS}; \
      wildcard bins instr_fcvtsw = {INSTR_FCVTSW}; \
      wildcard bins instr_fcvtswu = {INSTR_FCVTSWU}; \
      wildcard bins instr_fmvsx = {INSTR_FMVSX}; \
      // LOAD STORE \
      wildcard bins instr_lb = {INSTR_LB}; \
      wildcard bins instr_lh = {INSTR_LH}; \
      wildcard bins instr_lw = {INSTR_LW}; \
      wildcard bins instr_lbu = {INSTR_LBU}; \
      wildcard bins instr_lhu = {INSTR_LHU}; \
      wildcard bins instr_sb = {INSTR_SB}; \
      wildcard bins instr_sh = {INSTR_SH}; \
      wildcard bins instr_sw = {INSTR_SW}; \
      // CUSTOM_0 \
      // Post-Increment Register-Immediate Load \
      wildcard bins instr_cvlbi = {INSTR_CVLBI}; \
      wildcard bins instr_cvlbui = {INSTR_CVLBUI}; \
      wildcard bins instr_cvlhi = {INSTR_CVLHI}; \
      wildcard bins instr_cvlhui = {INSTR_CVLHUI}; \
      wildcard bins instr_cvlwi = {INSTR_CVLWI}; \
      // Event Load \
      wildcard bins instr_cvelw = {INSTR_CVELW}; \
      // CUSTOM_1 \
      // Post-Increment Register-Register Load \
      wildcard bins instr_cvlbr = {INSTR_CVLBR}; \
      wildcard bins instr_cvlbur = {INSTR_CVLBUR}; \
      wildcard bins instr_cvlhr = {INSTR_CVLHR}; \
      wildcard bins instr_cvlhur = {INSTR_CVLHUR}; \
      wildcard bins instr_cvlwr = {INSTR_CVLWR}; \
      // Register-Register Load \
      wildcard bins instr_cvlbrr = {INSTR_CVLBRR}; \
      wildcard bins instr_cvlburr = {INSTR_CVLBURR}; \
      wildcard bins instr_cvlhrr = {INSTR_CVLHRR}; \
      wildcard bins instr_cvlhurr = {INSTR_CVLHURR}; \
      wildcard bins instr_cvlwrr = {INSTR_CVLWRR}; \
      // Post-Increment Register-Immediate Store \
      wildcard bins instr_cvsbi = {INSTR_CVSBI}; \
      wildcard bins instr_cvshi = {INSTR_CVSHI}; \
      wildcard bins instr_cvswi = {INSTR_CVSWI}; \
      // Post-Increment Register-Register Store operations encoding \
      wildcard bins instr_cvsbr = {INSTR_CVSBR}; \
      wildcard bins instr_cvshr = {INSTR_CVSHR}; \
      wildcard bins instr_cvswr = {INSTR_CVSWR}; \
      // Register-Register Store operations \
      wildcard bins instr_cvsbrr = {INSTR_CVSBRR}; \
      wildcard bins instr_cvshrr = {INSTR_CVSHRR}; \
      wildcard bins instr_cvswrr = {INSTR_CVSWRR}; \
      // Hardware Loops \
      wildcard bins instr_cvstarti0 = {INSTR_CVSTARTI0}; \
      wildcard bins instr_cvstart0 = {INSTR_CVSTART0}; \
      wildcard bins instr_cvsendi0 = {INSTR_CVSENDI0}; \
      wildcard bins instr_cvend0 = {INSTR_CVEND0}; \
      wildcard bins instr_cvcounti0 = {INSTR_CVCOUNTI0}; \
      wildcard bins instr_cvcount0 = {INSTR_CVCOUNT0}; \
      wildcard bins instr_cvsetupi0 = {INSTR_CVSETUPI0}; \
      wildcard bins instr_cvsetup0 = {INSTR_CVSETUP0}; \
      wildcard bins instr_cvstarti1 = {INSTR_CVSTARTI1}; \
      wildcard bins instr_cvstart1 = {INSTR_CVSTART1}; \
      wildcard bins instr_cvsendi1 = {INSTR_CVSENDI1}; \
      wildcard bins instr_cvend1 = {INSTR_CVEND1}; \
      wildcard bins instr_cvcounti1 = {INSTR_CVCOUNTI1}; \
      wildcard bins instr_cvcount1 = {INSTR_CVCOUNT1}; \
      wildcard bins instr_cvsetupi1 = {INSTR_CVSETUPI1}; \
      wildcard bins instr_cvsetup1 = {INSTR_CVSETUP1}; \
      wildcard bins instr_ff1 = {INSTR_FF1}; \
      wildcard bins instr_fl1 = {INSTR_FL1}; \
      wildcard bins instr_clb = {INSTR_CLB}; \
      wildcard bins instr_cnt = {INSTR_CNT}; \
      wildcard bins instr_exths = {INSTR_EXTHS}; \
      wildcard bins instr_exthz = {INSTR_EXTHZ}; \
      wildcard bins instr_extbs = {INSTR_EXTBS}; \
      wildcard bins instr_extbz = {INSTR_EXTBZ}; \
      wildcard bins instr_paddnr = {INSTR_PADDNR}; \
      wildcard bins instr_paddunr = {INSTR_PADDUNR}; \
      wildcard bins instr_paddrnr = {INSTR_PADDRNR}; \
      wildcard bins instr_paddurnr = {INSTR_PADDURNR}; \
      wildcard bins instr_psubnr = {INSTR_PSUBNR}; \
      wildcard bins instr_psubunr = {INSTR_PSUBUNR}; \
      wildcard bins instr_psubrnr = {INSTR_PSUBRNR}; \
      wildcard bins instr_psuburnr = {INSTR_PSUBURNR}; \
      wildcard bins instr_pabs = {INSTR_PABS}; \
      wildcard bins instr_pclip = {INSTR_PCLIP}; \
      wildcard bins instr_pclipu = {INSTR_PCLIPU}; \
      wildcard bins instr_pclipr = {INSTR_PCLIPR}; \
      wildcard bins instr_pclipur = {INSTR_PCLIPUR}; \
      wildcard bins instr_pslet = {INSTR_PSLET}; \
      wildcard bins instr_psletu = {INSTR_PSLETU}; \
      wildcard bins instr_pmin = {INSTR_PMIN}; \
      wildcard bins instr_pminu = {INSTR_PMINU}; \
      wildcard bins instr_pmax = {INSTR_PMAX}; \
      wildcard bins instr_pmaxu = {INSTR_PMAXU}; \
      wildcard bins instr_ror = {INSTR_ROR}; \
      wildcard bins instr_pbextr = {INSTR_PBEXTR}; \
      wildcard bins instr_pbextur = {INSTR_PBEXTUR}; \
      wildcard bins instr_pbinsr = {INSTR_PBINSR}; \
      wildcard bins instr_pbclrr = {INSTR_PBCLRR}; \
      wildcard bins instr_pbsetr = {INSTR_PBSETR}; \
      wildcard bins instr_pmac = {INSTR_PMAC}; \
      wildcard bins instr_pmsu = {INSTR_PMSU}; \
      // CUSTOM_2 \
      wildcard bins instr_pbext = {INSTR_PBEXT}; \
      wildcard bins instr_pbextu = {INSTR_PBEXTU}; \
      wildcard bins instr_pbins = {INSTR_PBINS}; \
      wildcard bins instr_pbclr = {INSTR_PBCLR}; \
      wildcard bins instr_pbset = {INSTR_PBSET}; \
      wildcard bins instr_pbrev = {INSTR_PBREV}; \
      wildcard bins instr_paddn = {INSTR_PADDN}; \
      wildcard bins instr_paddun = {INSTR_PADDUN}; \
      wildcard bins instr_paddrn = {INSTR_PADDRN}; \
      wildcard bins instr_paddurn = {INSTR_PADDURN}; \
      wildcard bins instr_psubn = {INSTR_PSUBN}; \
      wildcard bins instr_psubun = {INSTR_PSUBUN}; \
      wildcard bins instr_psubrn = {INSTR_PSUBRN}; \
      wildcard bins instr_psuburn = {INSTR_PSUBURN}; \
      wildcard bins instr_pmulsn = {INSTR_PMULSN}; \
      wildcard bins instr_pmulhhsn = {INSTR_PMULHHSN}; \
      wildcard bins instr_pmulsrn = {INSTR_PMULSRN}; \
      wildcard bins instr_pmulhhsrn = {INSTR_PMULHHSRN}; \
      wildcard bins instr_pmulun = {INSTR_PMULUN}; \
      wildcard bins instr_pmulhhun = {INSTR_PMULHHUN}; \
      wildcard bins instr_pmulurn = {INSTR_PMULURN}; \
      wildcard bins instr_pmulhhurn = {INSTR_PMULHHURN}; \
      wildcard bins instr_pmacsn = {INSTR_PMACSN}; \
      wildcard bins instr_pmachhsn = {INSTR_PMACHHSN}; \
      wildcard bins instr_pmacsrn = {INSTR_PMACSRN}; \
      wildcard bins instr_pmachhsrn = {INSTR_PMACHHSRN}; \
      wildcard bins instr_pmacun = {INSTR_PMACUN}; \
      wildcard bins instr_pmachhun = {INSTR_PMACHHUN}; \
      wildcard bins instr_pmacurn = {INSTR_PMACURN}; \
      wildcard bins instr_pmachhurn = {INSTR_PMACHHURN}; \
      // CUSTOM_3 \
      // SIMD ALU \
      wildcard bins instr_cvaddh = {INSTR_CVADDH}; \
      wildcard bins instr_cvaddsch = {INSTR_CVADDSCH}; \
      wildcard bins instr_cvaddscih = {INSTR_CVADDSCIH}; \
      wildcard bins instr_cvaddb = {INSTR_CVADDB}; \
      wildcard bins instr_cvaddscb = {INSTR_CVADDSCB}; \
      wildcard bins instr_cvaddscib = {INSTR_CVADDSCIB}; \
      wildcard bins instr_cvsubh = {INSTR_CVSUBH}; \
      wildcard bins instr_cvsubsch = {INSTR_CVSUBSCH}; \
      wildcard bins instr_cvsubscih = {INSTR_CVSUBSCIH}; \
      wildcard bins instr_cvsubb = {INSTR_CVSUBB}; \
      wildcard bins instr_cvsubscb = {INSTR_CVSUBSCB}; \
      wildcard bins instr_cvsubscib = {INSTR_CVSUBSCIB}; \
      wildcard bins instr_cvavgh = {INSTR_CVAVGH}; \
      wildcard bins instr_cvavgsch = {INSTR_CVAVGSCH}; \
      wildcard bins instr_cvavgscih = {INSTR_CVAVGSCIH}; \
      wildcard bins instr_cvavgb = {INSTR_CVAVGB}; \
      wildcard bins instr_cvavgscb = {INSTR_CVAVGSCB}; \
      wildcard bins instr_cvavgscib = {INSTR_CVAVGSCIB}; \
      wildcard bins instr_cvavguh = {INSTR_CVAVGUH}; \
      wildcard bins instr_cvavgusch = {INSTR_CVAVGUSCH}; \
      wildcard bins instr_cvavguscih = {INSTR_CVAVGUSCIH}; \
      wildcard bins instr_cvavgub = {INSTR_CVAVGUB}; \
      wildcard bins instr_cvavguscb = {INSTR_CVAVGUSCB}; \
      wildcard bins instr_cvavguscib = {INSTR_CVAVGUSCIB}; \
      wildcard bins instr_cvminh = {INSTR_CVMINH}; \
      wildcard bins instr_cvminsch = {INSTR_CVMINSCH}; \
      wildcard bins instr_cvminscih = {INSTR_CVMINSCIH}; \
      wildcard bins instr_cvminb = {INSTR_CVMINB}; \
      wildcard bins instr_cvminscb = {INSTR_CVMINSCB}; \
      wildcard bins instr_cvminscib = {INSTR_CVMINSCIB}; \
      wildcard bins instr_cvminuh = {INSTR_CVMINUH}; \
      wildcard bins instr_cvminusch = {INSTR_CVMINUSCH}; \
      wildcard bins instr_cvminuscih = {INSTR_CVMINUSCIH}; \
      wildcard bins instr_cvminub = {INSTR_CVMINUB}; \
      wildcard bins instr_cvminuscb = {INSTR_CVMINUSCB}; \
      wildcard bins instr_cvminuscib = {INSTR_CVMINUSCIB}; \
      wildcard bins instr_cvmaxh = {INSTR_CVMAXH}; \
      wildcard bins instr_cvmaxsch = {INSTR_CVMAXSCH}; \
      wildcard bins instr_cvmaxscih = {INSTR_CVMAXSCIH}; \
      wildcard bins instr_cvmaxb = {INSTR_CVMAXB}; \
      wildcard bins instr_cvmaxscb = {INSTR_CVMAXSCB}; \
      wildcard bins instr_cvmaxscib = {INSTR_CVMAXSCIB}; \
      wildcard bins instr_cvmaxuh = {INSTR_CVMAXUH}; \
      wildcard bins instr_cvmaxusch = {INSTR_CVMAXUSCH}; \
      wildcard bins instr_cvmaxuscih = {INSTR_CVMAXUSCIH}; \
      wildcard bins instr_cvmaxub = {INSTR_CVMAXUB}; \
      wildcard bins instr_cvmaxuscb = {INSTR_CVMAXUSCB}; \
      wildcard bins instr_cvmaxuscib = {INSTR_CVMAXUSCIB}; \
      wildcard bins instr_cvsrlh = {INSTR_CVSRLH}; \
      wildcard bins instr_cvsrlsch = {INSTR_CVSRLSCH}; \
      wildcard bins instr_cvsrlscih = {INSTR_CVSRLSCIH}; \
      wildcard bins instr_cvsrlb = {INSTR_CVSRLB}; \
      wildcard bins instr_cvsrlscb = {INSTR_CVSRLSCB}; \
      wildcard bins instr_cvsrlscib = {INSTR_CVSRLSCIB}; \
      wildcard bins instr_cvsrah = {INSTR_CVSRAH}; \
      wildcard bins instr_cvsrasch = {INSTR_CVSRASCH}; \
      wildcard bins instr_cvsrascih = {INSTR_CVSRASCIH}; \
      wildcard bins instr_cvsrab = {INSTR_CVSRAB}; \
      wildcard bins instr_cvsrascb = {INSTR_CVSRASCB}; \
      wildcard bins instr_cvsrascib = {INSTR_CVSRASCIB}; \
      wildcard bins instr_cvsllh = {INSTR_CVSLLH}; \
      wildcard bins instr_cvsllsch = {INSTR_CVSLLSCH}; \
      wildcard bins instr_cvsllscih = {INSTR_CVSLLSCIH}; \
      wildcard bins instr_cvsllb = {INSTR_CVSLLB}; \
      wildcard bins instr_cvsllscb = {INSTR_CVSLLSCB}; \
      wildcard bins instr_cvsllscib = {INSTR_CVSLLSCIB}; \
      wildcard bins instr_cvorh = {INSTR_CVORH}; \
      wildcard bins instr_cvorsch = {INSTR_CVORSCH}; \
      wildcard bins instr_cvorscih = {INSTR_CVORSCIH}; \
      wildcard bins instr_cvorb = {INSTR_CVORB}; \
      wildcard bins instr_cvorscb = {INSTR_CVORSCB}; \
      wildcard bins instr_cvorscib = {INSTR_CVORSCIB}; \
      wildcard bins instr_cvxorh = {INSTR_CVXORH}; \
      wildcard bins instr_cvxorsch = {INSTR_CVXORSCH}; \
      wildcard bins instr_cvxorscih = {INSTR_CVXORSCIH}; \
      wildcard bins instr_cvxorb = {INSTR_CVXORB}; \
      wildcard bins instr_cvxorscb = {INSTR_CVXORSCB}; \
      wildcard bins instr_cvxorscib = {INSTR_CVXORSCIB}; \
      wildcard bins instr_cvandh = {INSTR_CVANDH}; \
      wildcard bins instr_cvandsch = {INSTR_CVANDSCH}; \
      wildcard bins instr_cvandscih = {INSTR_CVANDSCIH}; \
      wildcard bins instr_cvandb = {INSTR_CVANDB}; \
      wildcard bins instr_cvandscb = {INSTR_CVANDSCB}; \
      wildcard bins instr_cvandscib = {INSTR_CVANDSCIB}; \
      wildcard bins instr_cvabsh = {INSTR_CVABSH}; \
      wildcard bins instr_cvabsb = {INSTR_CVABSB}; \
      wildcard bins instr_cvextracth = {INSTR_CVEXTRACTH}; \
      wildcard bins instr_cvextractb = {INSTR_CVEXTRACTB}; \
      wildcard bins instr_cvextractuh = {INSTR_CVEXTRACTUH}; \
      wildcard bins instr_cvextractub = {INSTR_CVEXTRACTUB}; \
      wildcard bins instr_cvinserth = {INSTR_CVINSERTH}; \
      wildcard bins instr_cvinsertb = {INSTR_CVINSERTB}; \
      wildcard bins instr_cvdotuph = {INSTR_CVDOTUPH}; \
      wildcard bins instr_cvdotupsch = {INSTR_CVDOTUPSCH}; \
      wildcard bins instr_cvdotupscih = {INSTR_CVDOTUPSCIH}; \
      wildcard bins instr_cvdotupb = {INSTR_CVDOTUPB}; \
      wildcard bins instr_cvdotupscb = {INSTR_CVDOTUPSCB}; \
      wildcard bins instr_cvdotupscib = {INSTR_CVDOTUPSCIB}; \
      wildcard bins instr_cvdotusph = {INSTR_CVDOTUSPH}; \
      wildcard bins instr_cvdotuspsch = {INSTR_CVDOTUSPSCH}; \
      wildcard bins instr_cvdotuspscih = {INSTR_CVDOTUSPSCIH}; \
      wildcard bins instr_cvdotuspb = {INSTR_CVDOTUSPB}; \
      wildcard bins instr_cvdotuspscb = {INSTR_CVDOTUSPSCB}; \
      wildcard bins instr_cvdotuspscib = {INSTR_CVDOTUSPSCIB}; \
      wildcard bins instr_cvdotsph = {INSTR_CVDOTSPH}; \
      wildcard bins instr_cvdotspsch = {INSTR_CVDOTSPSCH}; \
      wildcard bins instr_cvdotspscih = {INSTR_CVDOTSPSCIH}; \
      wildcard bins instr_cvdotspb = {INSTR_CVDOTSPB}; \
      wildcard bins instr_cvdotspscb = {INSTR_CVDOTSPSCB}; \
      wildcard bins instr_cvdotspscib = {INSTR_CVDOTSPSCIB}; \
      wildcard bins instr_cvsdotuph = {INSTR_CVSDOTUPH}; \
      wildcard bins instr_cvsdotupsch = {INSTR_CVSDOTUPSCH}; \
      wildcard bins instr_cvsdotupscih = {INSTR_CVSDOTUPSCIH}; \
      wildcard bins instr_cvsdotupb = {INSTR_CVSDOTUPB}; \
      wildcard bins instr_cvsdotupscb = {INSTR_CVSDOTUPSCB}; \
      wildcard bins instr_cvsdotupscib = {INSTR_CVSDOTUPSCIB}; \
      wildcard bins instr_cvsdotusph = {INSTR_CVSDOTUSPH}; \
      wildcard bins instr_cvsdotuspsch = {INSTR_CVSDOTUSPSCH}; \
      wildcard bins instr_cvsdotuspscih = {INSTR_CVSDOTUSPSCIH}; \
      wildcard bins instr_cvsdotuspb = {INSTR_CVSDOTUSPB}; \
      wildcard bins instr_cvsdotuspscb = {INSTR_CVSDOTUSPSCB}; \
      wildcard bins instr_cvsdotuspscib = {INSTR_CVSDOTUSPSCIB}; \
      wildcard bins instr_cvsdotsph = {INSTR_CVSDOTSPH}; \
      wildcard bins instr_cvsdotspsch = {INSTR_CVSDOTSPSCH}; \
      wildcard bins instr_cvsdotspscih = {INSTR_CVSDOTSPSCIH}; \
      wildcard bins instr_cvsdotspb = {INSTR_CVSDOTSPB}; \
      wildcard bins instr_cvsdotspscb = {INSTR_CVSDOTSPSCB}; \
      wildcard bins instr_cvsdotspscib = {INSTR_CVSDOTSPSCIB}; \
      wildcard bins instr_cvshuffleh = {INSTR_CVSHUFFLEH}; \
      wildcard bins instr_cvshufflescih = {INSTR_CVSHUFFLESCIH}; \
      wildcard bins instr_cvshuffleb = {INSTR_CVSHUFFLEB}; \
      wildcard bins instr_cvshufflel0scib = {INSTR_CVSHUFFLEL0SCIB}; \
      wildcard bins instr_cvshufflel1scib = {INSTR_CVSHUFFLEL1SCIB}; \
      wildcard bins instr_cvshufflel2scib = {INSTR_CVSHUFFLEL2SCIB}; \
      wildcard bins instr_cvshufflel3scib = {INSTR_CVSHUFFLEL3SCIB}; \
      wildcard bins instr_cvshuffle2h = {INSTR_CVSHUFFLE2H}; \
      wildcard bins instr_cvshuffle2b = {INSTR_CVSHUFFLE2B}; \
      wildcard bins instr_cvpack = {INSTR_CVPACK}; \
      wildcard bins instr_cvpackh = {INSTR_CVPACKH}; \
      wildcard bins instr_cvpackhib = {INSTR_CVPACKHIB}; \
      wildcard bins instr_cvpacklob = {INSTR_CVPACKLOB}; \
      // SIMD COMPARISON \
      wildcard bins instr_cvcmpeqh = {INSTR_CVCMPEQH}; \
      wildcard bins instr_cvcmpeqsch = {INSTR_CVCMPEQSCH}; \
      wildcard bins instr_cvcmpeqscih = {INSTR_CVCMPEQSCIH}; \
      wildcard bins instr_cvcmpeqb = {INSTR_CVCMPEQB}; \
      wildcard bins instr_cvcmpeqscb = {INSTR_CVCMPEQSCB}; \
      wildcard bins instr_cvcmpeqscib = {INSTR_CVCMPEQSCIB}; \
      wildcard bins instr_cvcmpneh = {INSTR_CVCMPNEH}; \
      wildcard bins instr_cvcmpnesch = {INSTR_CVCMPNESCH}; \
      wildcard bins instr_cvcmpnescih = {INSTR_CVCMPNESCIH}; \
      wildcard bins instr_cvcmpneb = {INSTR_CVCMPNEB}; \
      wildcard bins instr_cvcmpnescb = {INSTR_CVCMPNESCB}; \
      wildcard bins instr_cvcmpnescib = {INSTR_CVCMPNESCIB}; \
      wildcard bins instr_cvcmpgth = {INSTR_CVCMPGTH}; \
      wildcard bins instr_cvcmpgtsch = {INSTR_CVCMPGTSCH}; \
      wildcard bins instr_cvcmpgtscih = {INSTR_CVCMPGTSCIH}; \
      wildcard bins instr_cvcmpgtb = {INSTR_CVCMPGTB}; \
      wildcard bins instr_cvcmpgtscb = {INSTR_CVCMPGTSCB}; \
      wildcard bins instr_cvcmpgtscib = {INSTR_CVCMPGTSCIB}; \
      wildcard bins instr_cvcmpgeh = {INSTR_CVCMPGEH}; \
      wildcard bins instr_cvcmpgesch = {INSTR_CVCMPGESCH}; \
      wildcard bins instr_cvcmpgescih = {INSTR_CVCMPGESCIH}; \
      wildcard bins instr_cvcmpgeb = {INSTR_CVCMPGEB}; \
      wildcard bins instr_cvcmpgescb = {INSTR_CVCMPGESCB}; \
      wildcard bins instr_cvcmpgescib = {INSTR_CVCMPGESCIB}; \
      wildcard bins instr_cvcmplth = {INSTR_CVCMPLTH}; \
      wildcard bins instr_cvcmpltsch = {INSTR_CVCMPLTSCH}; \
      wildcard bins instr_cvcmpltscih = {INSTR_CVCMPLTSCIH}; \
      wildcard bins instr_cvcmpltb = {INSTR_CVCMPLTB}; \
      wildcard bins instr_cvcmpltscb = {INSTR_CVCMPLTSCB}; \
      wildcard bins instr_cvcmpltscib = {INSTR_CVCMPLTSCIB}; \
      wildcard bins instr_cvcmpleh = {INSTR_CVCMPLEH}; \
      wildcard bins instr_cvcmplesch = {INSTR_CVCMPLESCH}; \
      wildcard bins instr_cvcmplescih = {INSTR_CVCMPLESCIH}; \
      wildcard bins instr_cvcmpleb = {INSTR_CVCMPLEB}; \
      wildcard bins instr_cvcmplescb = {INSTR_CVCMPLESCB}; \
      wildcard bins instr_cvcmplescib = {INSTR_CVCMPLESCIB}; \
      wildcard bins instr_cvcmpgtuh = {INSTR_CVCMPGTUH}; \
      wildcard bins instr_cvcmpgtusch = {INSTR_CVCMPGTUSCH}; \
      wildcard bins instr_cvcmpgtuscih = {INSTR_CVCMPGTUSCIH}; \
      wildcard bins instr_cvcmpgtub = {INSTR_CVCMPGTUB}; \
      wildcard bins instr_cvcmpgtuscb = {INSTR_CVCMPGTUSCB}; \
      wildcard bins instr_cvcmpgtuscib = {INSTR_CVCMPGTUSCIB}; \
      wildcard bins instr_cvcmpgeuh = {INSTR_CVCMPGEUH}; \
      wildcard bins instr_cvcmpgeusch = {INSTR_CVCMPGEUSCH}; \
      wildcard bins instr_cvcmpgeuscih = {INSTR_CVCMPGEUSCIH}; \
      wildcard bins instr_cvcmpgeub = {INSTR_CVCMPGEUB}; \
      wildcard bins instr_cvcmpgeuscb = {INSTR_CVCMPGEUSCB}; \
      wildcard bins instr_cvcmpgeuscib = {INSTR_CVCMPGEUSCIB}; \
      wildcard bins instr_cvcmpltuh = {INSTR_CVCMPLTUH}; \
      wildcard bins instr_cvcmpltusch = {INSTR_CVCMPLTUSCH}; \
      wildcard bins instr_cvcmpltuscih = {INSTR_CVCMPLTUSCIH}; \
      wildcard bins instr_cvcmpltub = {INSTR_CVCMPLTUB}; \
      wildcard bins instr_cvcmpltuscb = {INSTR_CVCMPLTUSCB}; \
      wildcard bins instr_cvcmpltuscib = {INSTR_CVCMPLTUSCIB}; \
      wildcard bins instr_cvcmpleuh = {INSTR_CVCMPLEUH}; \
      wildcard bins instr_cvcmpleusch = {INSTR_CVCMPLEUSCH}; \
      wildcard bins instr_cvcmpleuscih = {INSTR_CVCMPLEUSCIH}; \
      wildcard bins instr_cvcmpleub = {INSTR_CVCMPLEUB}; \
      wildcard bins instr_cvcmpleuscb = {INSTR_CVCMPLEUSCB}; \
      wildcard bins instr_cvcmpleuscib = {INSTR_CVCMPLEUSCIB}; \
      // SIMD CPLX \
      wildcard bins instr_cvcplxmulr = {INSTR_CVCPLXMULR}; \
      wildcard bins instr_cvcplxmulrdiv2 = {INSTR_CVCPLXMULRDIV2}; \
      wildcard bins instr_cvcplxmulrdiv4 = {INSTR_CVCPLXMULRDIV4}; \
      wildcard bins instr_cvcplxmulrdiv8 = {INSTR_CVCPLXMULRDIV8}; \
      wildcard bins instr_cvcplxmuli = {INSTR_CVCPLXMULI}; \
      wildcard bins instr_cvcplxmulidiv2 = {INSTR_CVCPLXMULIDIV2}; \
      wildcard bins instr_cvcplxmulidiv4 = {INSTR_CVCPLXMULIDIV4}; \
      wildcard bins instr_cvcplxmulidiv8 = {INSTR_CVCPLXMULIDIV8}; \
      wildcard bins instr_cvcplxconj = {INSTR_CVCPLXCONJ}; \
      wildcard bins instr_cvsubrotmj = {INSTR_CVSUBROTMJ}; \
      wildcard bins instr_cvsubrotmjdiv2 = {INSTR_CVSUBROTMJDIV2}; \
      wildcard bins instr_cvsubrotmjdiv4 = {INSTR_CVSUBROTMJDIV4}; \
      wildcard bins instr_cvsubrotmjdiv8 = {INSTR_CVSUBROTMJDIV8}; \
      wildcard bins instr_cvaddiv2 = {INSTR_CVADDIV2}; \
      wildcard bins instr_cvaddiv4 = {INSTR_CVADDIV4}; \
      wildcard bins instr_cvaddiv8 = {INSTR_CVADDIV8}; \
      wildcard bins instr_cvsubiv2 = {INSTR_CVSUBIV2}; \
      wildcard bins instr_cvsubiv4 = {INSTR_CVSUBIV4}; \
      wildcard bins instr_cvsubiv8 = {INSTR_CVSUBIV8}; \
      // Load-Store (RV32F) \
      wildcard bins instr_flw  = {{17'b?, 3'b010, 5'b?, OPCODE_LOAD_FP}}; \
      wildcard bins instr_fsw  = {{17'b?, 3'b010, 5'b?, OPCODE_STORE_FP}}; \
      // user-defined for any illegal instructions \
      wildcard bins instr_illegal_exception = {{INSN_ILLEGAL}}; \
      wildcard bins instr_ebreakm = {{INSN_EBREAKM}}; \
      // Others \
      illegal_bins other_instr = default; \
    } \
    ccp_hwloop_type_setup_insn_list : cross cp_hwloop_type, cp_hwloop_setup, cp_insn_list_in_hwloop; \
    ccp_hwloop_type_irq             : cross cp_hwloop_type, cp_hwloop_irq; \
    ccp_hwloop_type_dbg_mode        : cross cp_hwloop_type, cp_hwloop_dbg_mode; \
    ccp_hwloop_type_dbg_step_cnt    : cross cp_hwloop_type, cp_hwloop_dbg_step_cnt; \
  endgroup : cg_features_of_hwloop_``LOOP_IDX``

  `DEF_CG_CSR_HWLOOP(0)
  `DEF_CG_CSR_HWLOOP(1)
  `DEF_CG_FEATURES_OF_HWLOOP(0)
  `DEF_CG_FEATURES_OF_HWLOOP(1)

  // COVERGROUPS DEFINE HERE - START

  `uvm_component_utils(uvme_rv32x_hwloop_covg)

  function new(string name="uvme_rv32x_hwloop_covg", uvm_component parent=null);
    super.new(name, parent);
    `CG_CSR_HWLOOP(0)         = new(); `CG_CSR_HWLOOP(0).set_inst_name($sformatf("cg_csr_hwloop_0"));
    `CG_CSR_HWLOOP(1)         = new(); `CG_CSR_HWLOOP(1).set_inst_name($sformatf("cg_csr_hwloop_1"));
    `CG_FEATURES_OF_HWLOOP(0) = new(); `CG_FEATURES_OF_HWLOOP(0).set_inst_name($sformatf("cg_features_of_hwloop_0"));
    `CG_FEATURES_OF_HWLOOP(1) = new(); `CG_FEATURES_OF_HWLOOP(1).set_inst_name($sformatf("cg_features_of_hwloop_1"));
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!(uvm_config_db#(virtual uvmt_cv32e40p_rvvi_if)::get(this, "", "cv32e40p_rvvi_vif", cv32e40p_rvvi_vif))) begin
        `uvm_fatal(_header, "cv32e40p_rvvi_vif no found in uvm_config_db");
    end
  endfunction : build_phase

  // task to sample cg_csr_hwloop
  // covers below scenarioes: 
  //  - flow w/wo interrupt with short/long setup
  //  - interrupt happen before/during main hwloop (interrupt has hwloop with short/long setup)
  `define CHECK_N_SAMPLE_CSR_HWLOOP(TYPE) check_n_sample_csr_hwloop_``TYPE``();
  `define DEF_CHECK_N_SAMPLE_CSR_HWLOOP(TYPE) task check_n_sample_csr_hwloop_``TYPE``(); \
    for (int i=0; i<HWLOOP_NB; i++) begin \
      int short_setup_cnt = 0; // use for cv.setup (all start, end and count happen stimultenously in one cycle) \
      if (cv32e40p_rvvi_vif.csr_wb[CSR_LPSTART0_ADDR+i*4]) begin : UPDATE_LPSTART \
        csr_hwloop_``TYPE``.lp_start[i]    = cv32e40p_rvvi_vif.csr[CSR_LPSTART0_ADDR+i*4]; \
        csr_hwloop_``TYPE``.lp_start_wb[i] = cv32e40p_rvvi_vif.csr_wb[CSR_LPSTART0_ADDR+i*4]; \
        short_setup_cnt++; \
      end \
      if (cv32e40p_rvvi_vif.csr_wb[CSR_LPEND0_ADDR+i*4]) begin : UPDATE_LPEND \
        csr_hwloop_``TYPE``.lp_end[i]      = cv32e40p_rvvi_vif.csr[CSR_LPEND0_ADDR+i*4]; \
        csr_hwloop_``TYPE``.lp_end_wb[i]   = cv32e40p_rvvi_vif.csr_wb[CSR_LPEND0_ADDR+i*4]; \
        short_setup_cnt++; \
      end \
      if (cv32e40p_rvvi_vif.csr_wb[CSR_LPCOUNT0_ADDR+i*4]) begin : UPDATE_LPCOUNT \
        csr_hwloop_``TYPE``.lp_count[i]    = cv32e40p_rvvi_vif.csr[CSR_LPCOUNT0_ADDR+i*4]; \
        csr_hwloop_``TYPE``.lp_count_wb[i] = cv32e40p_rvvi_vif.csr_wb[CSR_LPCOUNT0_ADDR+i*4]; \
        short_setup_cnt++; \
      end \
      if (csr_hwloop_``TYPE``.lp_start_wb[i] && csr_hwloop_``TYPE``.lp_end_wb[i] && csr_hwloop_``TYPE``.lp_count_wb[i]) begin : SAMPLE_HWLOP_CSR \
        if (csr_hwloop_``TYPE``.lp_count[i] != 0) begin : SAMPLE_IF_TRUE \
          `uvm_info(_header, $sformatf("DEBUG - cg_csr_hwloop[%0d] - sampling csr_hwloop is %p", i, csr_hwloop_``TYPE``), UVM_DEBUG); \
          unique case (i) \
            0:  begin \
                `CG_CSR_HWLOOP(0).sample(csr_hwloop_``TYPE``); \
                `uvm_info(_header, $sformatf("DEBUG - cg_csr_hwloop[%0d] - get_inst_coverage = %.2f, get_coverage = %.2f", i, `CG_CSR_HWLOOP(0).get_inst_coverage(), `CG_CSR_HWLOOP(0).get_coverage), UVM_DEBUG); \
                end \
            1:  begin \
                `CG_CSR_HWLOOP(1).sample(csr_hwloop_``TYPE``); \
                `uvm_info(_header, $sformatf("DEBUG - cg_csr_hwloop[%0d] - get_inst_coverage = %.2f, get_coverage = %.2f", i, `CG_CSR_HWLOOP(1).get_inst_coverage(), `CG_CSR_HWLOOP(1).get_coverage), UVM_DEBUG); \
                end \
          endcase \
          // update hwloop_stat \
          hwloop_stat_``TYPE``.hwloop_csr.lp_start[i] = csr_hwloop_``TYPE``.lp_start[i]; \
          hwloop_stat_``TYPE``.hwloop_csr.lp_end[i]   = csr_hwloop_``TYPE``.lp_end[i]; \
          hwloop_stat_``TYPE``.hwloop_csr.lp_count[i] = csr_hwloop_``TYPE``.lp_count[i]; \
          if (short_setup_cnt == 3) \
            hwloop_stat_``TYPE``.hwloop_setup[i]      = SHORT; \
          else                       \
            hwloop_stat_``TYPE``.hwloop_setup[i]      = LONG; \
        end // SAMPLE_IF_TRUE \
        csr_hwloop_``TYPE`` = csr_hwloop_init; // reset struc \
      end // SAMPLE_HWLOP_CSR \
    end // for \
  endtask : check_n_sample_csr_hwloop_``TYPE``

  `DEF_CHECK_N_SAMPLE_CSR_HWLOOP(main)
  `DEF_CHECK_N_SAMPLE_CSR_HWLOOP(sub)

  // task to sample cg_features_of_hwloop
  // covers below scenarioes: 
  //  - flow w/wo interrupt with short/long setup
  //  - interrupt happen before/during main hwloop (interrupt has hwloop with short/long setup)
  string sub = "sub";
  string main = "main";
  `define CHECK_N_SAMPLE_HWLOOP(TYPE) check_n_sample_hwloop_``TYPE``();
  `define DEF_CHECK_N_SAMPLE_HWLOOP(TYPE) task check_n_sample_hwloop_``TYPE``(); \
    for (int i=0; i<HWLOOP_NB; i++) begin : UPDATE_HWLOOP_STAT \
      if (hwloop_stat_``TYPE``.hwloop_csr.lp_count[i] != 0) begin \
        if (is_pc_equal_lpstart(hwloop_stat_``TYPE``.hwloop_csr, i) && hwloop_stat_``TYPE``.track_lp_count[i] == 0) begin \
          hwloop_stat_``TYPE``.execute_instr_in_hwloop[i] = 1'b1; \
          hwloop_stat_``TYPE``.track_lp_count[i]          = hwloop_stat_``TYPE``.hwloop_csr.lp_count[i]; \
          if      ( hwloop_stat_``TYPE``.execute_instr_in_hwloop[0] &&  hwloop_stat_``TYPE``.execute_instr_in_hwloop[1]) hwloop_stat_``TYPE``.hwloop_type = NESTED; \
          else if ( hwloop_stat_``TYPE``.execute_instr_in_hwloop[0] && !hwloop_stat_``TYPE``.execute_instr_in_hwloop[1]) hwloop_stat_``TYPE``.hwloop_type = SINGLE; \
          else if (!hwloop_stat_``TYPE``.execute_instr_in_hwloop[0] &&  hwloop_stat_``TYPE``.execute_instr_in_hwloop[1]) hwloop_stat_``TYPE``.hwloop_type = SINGLE; \
        end \
      end \
    end // UPDATE_HWLOOP_STAT \
    for (int i=0; i<HWLOOP_NB; i++) begin : COLLECT_INSTR \
      if (hwloop_stat_``TYPE``.execute_instr_in_hwloop[i]) begin \
        unique case (i) \
          0 : begin // nested or single is the same \
                if (!done_insn_list_capture_``TYPE``[i]) begin \
                  if (is_illegal)       insn_list_in_hwloop_``TYPE``[i].push_back(INSN_ILLEGAL); \
                  else if (is_ebreakm)  insn_list_in_hwloop_``TYPE``[i].push_back(INSN_EBREAKM); \
                  else                  insn_list_in_hwloop_``TYPE``[i].push_back(cv32e40p_rvvi_vif.insn); \
                end \
                else if (is_ebreakm && cv32e40p_rvvi_vif.insn == INSTR_EBREAK) begin \
                  insn_list_in_hwloop_``TYPE``[i].push_back(INSN_EBREAKM); \
                end \
                if (is_pc_equal_lpend(hwloop_stat_``TYPE``.hwloop_csr, i)) begin \
                  hwloop_stat_``TYPE``.track_lp_count[i]--; \
                  assert(hwloop_stat_``TYPE``.track_lp_count[i] >= 0); \
                end \
                if (hwloop_stat_``TYPE``.track_lp_count[i] != hwloop_stat_``TYPE``.hwloop_csr.lp_count[i]) done_insn_list_capture_``TYPE``[i] = 1; \
              end \
          1 : begin // in nested, skip when executing hwloop0  \
                if (hwloop_stat_``TYPE``.hwloop_type == NESTED && hwloop_stat_``TYPE``.track_lp_count[0] != 0) begin \
                  in_nested_loop0 = 1; continue; \
                end \
                else if (hwloop_stat_``TYPE``.hwloop_type == NESTED && hwloop_stat_``TYPE``.track_lp_count[0] == 0 && in_nested_loop0) begin \
                  in_nested_loop0 = 0; continue; \
                end \
                if (!done_insn_list_capture_``TYPE``[i]) begin \
                  if (is_illegal)       insn_list_in_hwloop_``TYPE``[i].push_back(INSN_ILLEGAL); \
                  else if (is_ebreakm)  insn_list_in_hwloop_``TYPE``[i].push_back(INSN_EBREAKM); \
                  else                  insn_list_in_hwloop_``TYPE``[i].push_back(cv32e40p_rvvi_vif.insn); \
                end \
                else if (is_ebreakm && cv32e40p_rvvi_vif.insn == INSTR_EBREAK) begin \
                  insn_list_in_hwloop_``TYPE``[i].push_back(INSN_EBREAKM); \
                end \
                if (is_pc_equal_lpend(hwloop_stat_``TYPE``.hwloop_csr, i)) begin \
                  hwloop_stat_``TYPE``.track_lp_count[i]--; \
                  assert(hwloop_stat_``TYPE``.track_lp_count[i] >= 0); \
                end \
                if (hwloop_stat_``TYPE``.track_lp_count[i] != hwloop_stat_``TYPE``.hwloop_csr.lp_count[i]) done_insn_list_capture_``TYPE``[i] = 1; \
              end \
        endcase  \
      end \
    end // COLLECT_INSTR \
    if ( \
      (hwloop_stat_``TYPE``.hwloop_type == NESTED && done_insn_list_capture_``TYPE``[1] && hwloop_stat_``TYPE``.track_lp_count[1] == 0) || \
      (hwloop_stat_``TYPE``.hwloop_type == SINGLE && done_insn_list_capture_``TYPE``[1] && hwloop_stat_``TYPE``.track_lp_count[1] == 0) || \
      (hwloop_stat_``TYPE``.hwloop_type == SINGLE && done_insn_list_capture_``TYPE``[0] && hwloop_stat_``TYPE``.track_lp_count[0] == 0) \
    ) begin : SAMPLE_END_OF_HWLOOPS \
      for (int i=0; i<HWLOOP_NB; i++) begin \
        while (insn_list_in_hwloop_``TYPE``[i].size() != 0) begin \
          bit [31:0] insn_item, irq_item; \
          bit dbg_mode_item; \
          int unsigned dbg_step_cnt_item; \
          insn_item = insn_list_in_hwloop_``TYPE``[i].pop_front(); \
          if (irq_vect_``TYPE``[i].size() != 0) begin \
            irq_item = irq_vect_``TYPE``[i].pop_front(); \
            `uvm_info(_header, $sformatf("DEBUG - COLLECT_IRQ - idx:%0d - irq_item is %8h", i, irq_item), UVM_DEBUG); \
          end \
          if (dbg_mode_``TYPE``[i] != 0) begin \
            dbg_mode_item = dbg_mode_``TYPE``[i]; \
            dbg_mode_``TYPE``[i] = 0; \
          end \
          if (dbg_step_cnt_``TYPE``[i] != 0) begin \
            dbg_step_cnt_item = dbg_step_cnt_``TYPE``[i]; \
            dbg_step_cnt_``TYPE``[i] = 0; \
          end \
          `uvm_info(_header, $sformatf("DEBUG - COLLECT_INSTR - idx:%0d - insn_item is %8h", i, insn_item), UVM_DEBUG); \
          unique case (i) \
            0:  begin \
                  `CG_FEATURES_OF_HWLOOP(0).sample(hwloop_stat_``TYPE``, insn_item, irq_item, dbg_mode_item, dbg_step_cnt_item); \
                end \
            1:  begin  \
                  `CG_FEATURES_OF_HWLOOP(1).sample(hwloop_stat_``TYPE``, insn_item, irq_item, dbg_mode_item, dbg_step_cnt_item); \
                end \
          endcase \
        end \
        done_insn_list_capture_``TYPE``[i]  = 0; \
      end \
      hwloop_stat_``TYPE`` = hwloop_stat_init; \
    end // SAMPLE_END_OF_HWLOOPS \
  endtask : check_n_sample_hwloop_``TYPE``

  `DEF_CHECK_N_SAMPLE_HWLOOP(main)
  `DEF_CHECK_N_SAMPLE_HWLOOP(sub)

  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    fork // Background threads
      forever begin : TRAP_HANDLING
        wait (cv32e40p_rvvi_vif.clk && cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.trap);
        case (cv32e40p_rvvi_vif.insn)
          INSTR_EBREAK, INSN_CEBREAK : begin 
            if (cv32e40p_rvvi_vif.csr_dcsr_ebreakm) begin is_ebreakm = 1;  `uvm_info(_header, $sformatf("DEBUG - Trap[EBREAKM]"), UVM_DEBUG); end
            else                                    begin is_ebreak  = 1;  `uvm_info(_header, $sformatf("DEBUG - Trap[EBREAK]"), UVM_DEBUG); end
          end
          INSTR_ECALL  : begin is_ecall = 1;                 `uvm_info(_header, $sformatf("DEBUG - Trap[ECALL]"), UVM_DEBUG); end
          default      : begin is_illegal = 1;               `uvm_info(_header, $sformatf("DEBUG - Trap[ILLEGAL]"), UVM_DEBUG); end
        endcase
        if (!is_ebreakm) begin wait (cv32e40p_rvvi_vif.clk && cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.insn == INSTR_MRET); end
        else             begin wait (cv32e40p_rvvi_vif.clk && cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.insn == INSTR_DRET); end
        is_ebreak = 0; is_ebreakm = 0; is_ecall = 0; is_illegal = 0;
        `uvm_info(_header, $sformatf("DEBUG - Exit Trap"), UVM_DEBUG);
      end // TRAP_HANDLING
      forever begin : IRQ_REQ_WITHIN_HWLOOPS
        wait (hwloop_stat_main.execute_instr_in_hwloop[0] | hwloop_stat_main.execute_instr_in_hwloop[1] | hwloop_stat_sub.execute_instr_in_hwloop[0]  | hwloop_stat_sub.execute_instr_in_hwloop[1]);
        wait (cv32e40p_rvvi_vif.valid_irq != 0 && !is_irq); // async
        if (hwloop_stat_main.execute_instr_in_hwloop[0] && hwloop_stat_main.track_lp_count[0] !=0)                      irq_vect_main[0].push_back(cv32e40p_rvvi_vif.valid_irq);
        if (hwloop_stat_main.execute_instr_in_hwloop[1] && hwloop_stat_main.track_lp_count[1] !=0 && !in_nested_loop0)  irq_vect_main[1].push_back(cv32e40p_rvvi_vif.valid_irq);
        if (hwloop_stat_sub.execute_instr_in_hwloop[0]  && hwloop_stat_sub.track_lp_count[0] !=0)                       irq_vect_sub[0].push_back(cv32e40p_rvvi_vif.valid_irq);
        if (hwloop_stat_sub.execute_instr_in_hwloop[1]  && hwloop_stat_sub.track_lp_count[1] !=0 && !in_nested_loop0)   irq_vect_sub[1].push_back(cv32e40p_rvvi_vif.valid_irq);
        `uvm_info(_header, $sformatf("DEBUG - Async IRQ Req detected"), UVM_DEBUG);
        is_irq = 1;
      end // IRQ_REQ_WITHIN_HWLOOPS
      forever begin : IRQ_EXIT
        wait (hwloop_stat_main.execute_instr_in_hwloop[0] | hwloop_stat_main.execute_instr_in_hwloop[1] | hwloop_stat_sub.execute_instr_in_hwloop[0]  | hwloop_stat_sub.execute_instr_in_hwloop[1]);
        @(posedge cv32e40p_rvvi_vif.clk);
        if (is_irq && cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.insn == INSTR_MRET) begin
          `uvm_info(_header, $sformatf("DEBUG - Async IRQ Exit"), UVM_DEBUG);
          is_irq = 0;
        end
      end // IRQ_EXIT
      forever begin : DBG_REQ_WITHIN_HWLOOPS
        wait (hwloop_stat_main.execute_instr_in_hwloop[0] | hwloop_stat_main.execute_instr_in_hwloop[1] | hwloop_stat_sub.execute_instr_in_hwloop[0]  | hwloop_stat_sub.execute_instr_in_hwloop[1]);
        wait (cv32e40p_rvvi_vif.dbg_req && !is_dbg_mode); // async
        if (hwloop_stat_main.execute_instr_in_hwloop[0] && hwloop_stat_main.track_lp_count[0] !=0)                      dbg_mode_main[0] = 1;
        if (hwloop_stat_main.execute_instr_in_hwloop[1] && hwloop_stat_main.track_lp_count[1] !=0 && !in_nested_loop0)  dbg_mode_main[1] = 1;
        if (hwloop_stat_sub.execute_instr_in_hwloop[0]  && hwloop_stat_sub.track_lp_count[0] !=0)                       dbg_mode_sub[0] = 1;
        if (hwloop_stat_sub.execute_instr_in_hwloop[1]  && hwloop_stat_sub.track_lp_count[1] !=0 && !in_nested_loop0)   dbg_mode_sub[1] = 1;
        `uvm_info(_header, $sformatf("DEBUG - Debug Mode Entry due to Async Debug Req"), UVM_DEBUG);
        @(posedge cv32e40p_rvvi_vif.valid); @(negedge cv32e40p_rvvi_vif.valid);
        is_dbg_mode = 1;
      end // DBG_REQ_WITHIN_HWLOOPS
      forever begin : DBG_TRIGGER_WITHIN_HWLOOPS
        wait (hwloop_stat_main.execute_instr_in_hwloop[0] | hwloop_stat_main.execute_instr_in_hwloop[1] | hwloop_stat_sub.execute_instr_in_hwloop[0]  | hwloop_stat_sub.execute_instr_in_hwloop[1]);
        @(posedge cv32e40p_rvvi_vif.clk);
        if (cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.csr_trig_execute && cv32e40p_rvvi_vif.csr_trig_pc == cv32e40p_rvvi_vif.pc_rdata) begin
          is_dbg_trigger = 1;
          `uvm_info(_header, $sformatf("DEBUG - Debug Mode Entry due to Trigger"), UVM_DEBUG);
        end
      end // DBG_TRIGGER_WITHIN_HWLOOPS
      forever begin : DBG_MODE_EXIT
        wait (hwloop_stat_main.execute_instr_in_hwloop[0] | hwloop_stat_main.execute_instr_in_hwloop[1] | hwloop_stat_sub.execute_instr_in_hwloop[0]  | hwloop_stat_sub.execute_instr_in_hwloop[1]);
        @(posedge cv32e40p_rvvi_vif.clk);
        if (is_dbg_mode && cv32e40p_rvvi_vif.valid && cv32e40p_rvvi_vif.insn == INSTR_DRET) begin
          `uvm_info(_header, $sformatf("DEBUG - Debug Mode Exit"), UVM_DEBUG);
          is_dbg_mode = 0; is_dbg_trigger = 0;
          if (cv32e40p_rvvi_vif.csr_dcsr_step) begin : DBG_STEP_WITHIN_HWLOOP
            @(posedge cv32e40p_rvvi_vif.valid); @(negedge cv32e40p_rvvi_vif.valid);
            if (hwloop_stat_main.execute_instr_in_hwloop[0] && hwloop_stat_main.track_lp_count[0] !=0)                      dbg_step_cnt_main[0]++;
            if (hwloop_stat_main.execute_instr_in_hwloop[1] && hwloop_stat_main.track_lp_count[1] !=0 && !in_nested_loop0)  dbg_step_cnt_main[1]++;
            if (hwloop_stat_sub.execute_instr_in_hwloop[0]  && hwloop_stat_sub.track_lp_count[0] !=0)                       dbg_step_cnt_sub[0]++;
            if (hwloop_stat_sub.execute_instr_in_hwloop[1]  && hwloop_stat_sub.track_lp_count[1] !=0 && !in_nested_loop0)   dbg_step_cnt_sub[1]++;
            is_dbg_mode = 1;
            `uvm_info(_header, $sformatf("DEBUG - Debug Mode Entry due to Step"), UVM_DEBUG);
          end // DBG_STEP_WITHIN_HWLOOP
        end
      end // DBG_MODE_EXIT
    join_none

    forever begin
      @(posedge cv32e40p_rvvi_vif.clk);
      if (cv32e40p_rvvi_vif.valid) begin : VALID_DETECTED
        if (enter_hwloop_sub) begin // [optional] for hwloops that outside main code
          `CHECK_N_SAMPLE_CSR_HWLOOP(sub);
          `CHECK_N_SAMPLE_HWLOOP(sub);
          if (!(is_ebreak || is_ebreakm || is_ecall || is_illegal || is_dbg_trigger)) enter_hwloop_sub = 0;
        end
        else begin : MAIN
          if (is_irq && cv32e40p_rvvi_vif.insn[6:0] == OPCODE_JAL) begin wait (!is_irq); continue; end
          if (is_dbg_mode) begin wait (!is_dbg_mode); continue; end
          `CHECK_N_SAMPLE_CSR_HWLOOP(main);
          `CHECK_N_SAMPLE_HWLOOP(main);
          if (is_ebreak || is_ebreakm || is_ecall || is_illegal || is_dbg_trigger) enter_hwloop_sub = 1;
        end
      end // VALID_DETECTED
    end // forever

  endtask : run_phase

  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (hwloop_stat_main == hwloop_stat_init && hwloop_stat_sub == hwloop_stat_init) begin
      `uvm_info(_header, $sformatf("DEBUG - No prematured hwloops when test done"), UVM_DEBUG);
    end
    else begin
      `uvm_error(_header, $sformatf("Detected prematured hwloops when test done. Please debug ... "));
    end
  endfunction : final_phase

  function bit is_pc_equal_lpstart(s_csr_hwloop csr_hwloop, int idx=0);
    if (cv32e40p_rvvi_vif.pc_rdata == csr_hwloop.lp_start[idx]) return 1;
    else return 0; 
  endfunction: is_pc_equal_lpstart

  function bit is_pc_equal_lpend(s_csr_hwloop csr_hwloop, int idx=0);
    if (cv32e40p_rvvi_vif.pc_rdata == csr_hwloop.lp_end[idx]-4) return 1;
    else return 0; 
  endfunction: is_pc_equal_lpend

endclass : uvme_rv32x_hwloop_covg

`endif
