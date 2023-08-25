//
// Copyright 2018 Google LLC
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
//
// Copyright 2023 OpenHW Group
// Copyright 2023 Dolphin Design
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier:Apache-2.0 WITH SHL-2.0
//*******************************************************************************************************************************************



//Class : cv32e40p_xpulp_hwloop_base_stream
//Base xpulp-hwloop stream class to create hwloop instructions
//Randomizing hwloop combinations - 1-3 loops, nested/not-nested
//
//This Stream for PULP HWLOOPs uses the format for as described below:
//*******************************************************************************************************************************************
//Nested HWLOOP random generated instruction structure
//*******************************************************************************************************************************************
//<loop1_setup_instructions>  -> using start->end->count for this stream TODO: randomize this order?
//<Random instructions till Loop START1 label>                  ->  use_setup_inst ? 0 : num_fill_instr_loop_ctrl_to_loop_start[1] - 1
//START1:
//    <Random instructions till <loop0_setup_instructions>>     ->  gen_nested_loop ? num_fill_instr_in_loop1_till_loop0_setup : NA
//    <loop0_setup_instructions>
//    <Random instructions till Loop START0 label>              ->  use_setup_inst ? 0 : num_fill_instr_loop_ctrl_to_loop_start[0] - 1
//    START0:
//           <Random instructions till Loop END0 label>         ->  num_hwloop_instr[0]
//    END0:
//    <Random instructions till Loop END1 label>                ->  Ramaining num_hwloop_instr[1]
//END1:
//<Random instructions>
//
//*******************************************************************************************************************************************
//
//
//*******************************************************************************************************************************************
//Not-Nested HWLOOP random generated instruction structure
//*******************************************************************************************************************************************
//<loop0/1_setup_instructions>  -> using start->end->count for this stream TODO: randomize this order?
//<Random instructions till Loop START0/1 label>                  ->  use_setup_inst ? 0 : num_fill_instr_loop_ctrl_to_loop_start[0/1] - 1
//START0/1:
//    <Random instructions till Loop END0/1 label>                ->  num_hwloop_instr[0/1]
//END0/1:
//<Random instructions>
//
//*******************************************************************************************************************************************

class cv32e40p_xpulp_hwloop_base_stream extends cv32e40p_xpulp_rand_stream;

  localparam MAX_HWLOOP_INSTR_GEN = 4095;

  rand riscv_reg_t      hwloop_avail_regs[];
  rand bit[1:0]         num_loops_active;
  rand bit              gen_nested_loop; //nested or not-nested hwloop
  rand bit              use_setup_inst[2];
  rand bit              use_loop_counti_inst[2];
  rand bit              use_loop_starti_inst[2];
  rand bit              use_loop_endi_inst[2];
  rand bit              use_loop_setupi_inst[2];
  rand bit[31:0]        hwloop_count[2];
  rand bit[11:0]        hwloop_counti[2];

  rand int unsigned     num_hwloop_instr[2];
  rand int unsigned     num_hwloop_ctrl_instr[2];
  rand int unsigned     num_fill_instr_loop_ctrl_to_loop_start[2];
  rand int unsigned     num_fill_instr_in_loop1_till_loop0_setup;
  rand bit              setup_l0_before_l1_start;

  int unsigned          num_instr_cv_start_to_loop_start_label[2];
  cv32e40p_instr        hwloop_setupi_instr[2];
  cv32e40p_instr        hwloop_setup_instr[2];
  cv32e40p_instr        hwloop_starti_instr[2];
  cv32e40p_instr        hwloop_start_instr[2];
  cv32e40p_instr        hwloop_endi_instr[2];
  cv32e40p_instr        hwloop_end_instr[2];
  cv32e40p_instr        hwloop_counti_instr[2];
  cv32e40p_instr        hwloop_count_instr[2];

  static int            stream_count = 0;

  riscv_instr_category_t xpulp_exclude_category[];

  `uvm_object_utils_begin(cv32e40p_xpulp_hwloop_base_stream)
      `uvm_field_int(num_loops_active, UVM_DEFAULT)
      `uvm_field_int(gen_nested_loop, UVM_DEFAULT)
      `uvm_field_sarray_int(use_setup_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_counti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_starti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_endi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_setupi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_count, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_counti, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_ctrl_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_fill_instr_loop_ctrl_to_loop_start, UVM_DEFAULT)
      `uvm_field_int(num_fill_instr_in_loop1_till_loop0_setup, UVM_DEFAULT)
      `uvm_field_int(setup_l0_before_l1_start, UVM_DEFAULT)
      `uvm_field_sarray_int(num_instr_cv_start_to_loop_start_label, UVM_DEFAULT)
  `uvm_object_utils_end

//
//***** CONSTRAINTS ******
//
  constraint x_inst_gen_c {
      soft num_of_xpulp_instr inside {[1:3]};
  }

  constraint rv_inst_gen_c {
      soft num_of_riscv_instr inside {[50:300]};
  }

  constraint avail_regs_pulp_instr_c {
    num_of_avail_regs inside {[10:20]};
    num_of_reserved_regs == 5;
  }

  constraint gen_hwloop_count_c {

      num_loops_active inside {1,2,3};

      foreach(hwloop_counti[i])
          hwloop_counti[i] inside {[0:200]};//TODO: check 0 is valid

      foreach(hwloop_count[i])
          hwloop_count[i] inside {[0:200]};//TODO: check 0 is valid
  }

  constraint num_hwloop_instr_c {
      solve num_hwloop_instr[0] before num_hwloop_instr[1];

      solve num_hwloop_instr[1] before num_fill_instr_in_loop1_till_loop0_setup,
                                       num_fill_instr_loop_ctrl_to_loop_start[0];

      solve use_loop_setupi_inst[1] before use_loop_setupi_inst[0];

      solve num_hwloop_ctrl_instr before num_hwloop_instr;

      solve gen_nested_loop, setup_l0_before_l1_start, use_setup_inst before num_hwloop_instr,
                                                                             num_fill_instr_loop_ctrl_to_loop_start,
                                                                             num_fill_instr_in_loop1_till_loop0_setup,
                                                                             num_hwloop_ctrl_instr;

      solve gen_nested_loop, setup_l0_before_l1_start before use_setup_inst,
                                                             use_loop_setupi_inst;

      solve gen_nested_loop before setup_l0_before_l1_start;


      setup_l0_before_l1_start dist {0 := 80, 1 := 20};

      if ((gen_nested_loop == 1) && (setup_l0_before_l1_start == 1)) {
          use_setup_inst[0] == 0;
          use_setup_inst[1] == 0;
          use_loop_setupi_inst[0] == 0;
          use_loop_setupi_inst[1] == 0;
      }

      if(use_setup_inst[0]) {
          num_fill_instr_loop_ctrl_to_loop_start[0] == 0;
          num_hwloop_ctrl_instr[0] == 1;
      } else {
          num_fill_instr_loop_ctrl_to_loop_start[0] inside {[0:7]};
          num_hwloop_ctrl_instr[0] == 3;
      }

      if(use_setup_inst[1]) {
          num_fill_instr_loop_ctrl_to_loop_start[1] == 0;
          num_hwloop_ctrl_instr[1] == 1;
      } else {
          num_fill_instr_loop_ctrl_to_loop_start[1] inside {[0:7]};
          num_hwloop_ctrl_instr[1] == 3;
      }

      if (gen_nested_loop == 1) {
          if (setup_l0_before_l1_start == 1) {
            num_hwloop_instr[0] inside {[3:97]};
            num_hwloop_instr[1] >= num_hwloop_instr[0] + 1 + 2; // 1 for cv.count0 ; 2 for end of loop req
            num_hwloop_instr[1] <= 99 + 1; // 1 for cv.count0
            num_fill_instr_in_loop1_till_loop0_setup inside {[0:20]};
            (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - 1); // 1 for cv.count0
          } else {
            if (use_setup_inst[1] && use_loop_setupi_inst[1]) { //with setupi only [4:0] uimmS range avail for end label
                if(use_setup_inst[0]) {
                  num_hwloop_instr[0] inside {[3:27]}; //TODO:in nested hwloop0 with setupi instr more than 27 instructions will have issue if setupi used for hwloop1?
                  num_hwloop_instr[1] >= num_hwloop_instr[0] + 1 + 2; // num_hwloop_ctrl_instr[0] == 1 ; 2 for end of loop req
                } else {
                  num_hwloop_instr[0] inside {[3:25]}; //TODO:in nested hwloop0 with setupi instr more than 27 instructions will have issue if setupi used for hwloop1?
                  num_hwloop_instr[1] >= num_hwloop_instr[0] + 3 + 2; // num_hwloop_ctrl_instr[0] == 3 ; 2 for end of loop req
                }
                //num_hwloop_instr[1] inside {[6:30]};
                num_hwloop_instr[1] <= 30; //with setupi only [4:0] uimmS range avail for end label which is equivalent to 30 hwloop body instructions
                num_fill_instr_in_loop1_till_loop0_setup inside {[0:5]};
            } else if(use_setup_inst[0] && use_loop_setupi_inst[0]) {
                num_hwloop_instr[0] inside {[3:30]};
                num_hwloop_instr[1] >= num_hwloop_instr[0] + 1 + 2; // num_hwloop_ctrl_instr[0] == 1 ; 2 for end of loop req
                num_hwloop_instr[1] <= 99 + num_hwloop_ctrl_instr[0];
                num_fill_instr_in_loop1_till_loop0_setup inside {[0:20]};
            } else {
                num_hwloop_instr[0] inside {[3:97]};
                num_hwloop_instr[1] >= num_hwloop_instr[0] + num_hwloop_ctrl_instr[0] + 2;
                num_hwloop_instr[1] <= 99 + num_hwloop_ctrl_instr[0];
                num_fill_instr_in_loop1_till_loop0_setup inside {[0:20]};
            }
            (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - num_hwloop_ctrl_instr[0]);
          }
      } else {
          if(use_setup_inst[1] && use_loop_setupi_inst[1]) {
              num_hwloop_instr[1] inside {[3:30]};
          } else {
              num_hwloop_instr[1] inside {[3:100]};
          }
          if(use_setup_inst[0] && use_loop_setupi_inst[0]) {
              num_hwloop_instr[0] inside {[3:30]};
          } else {
              num_hwloop_instr[0] inside {[3:100]};
          }
          num_fill_instr_in_loop1_till_loop0_setup == 0;
      }
  }


  function new(string name = "cv32e40p_xpulp_hwloop_base_stream");
      super.new(name);
      stream_count++;
  endfunction : new

  function void pre_randomize();
      super.pre_randomize();
  endfunction : pre_randomize

  function void post_randomize();
      uvm_default_printer.knobs.begin_elements = -1;
      this.print();
      gen_xpulp_hwloop_control_instr();
  endfunction : post_randomize

  //Gen pseudo instruction LA to initialize gpr
  virtual function void initialize_gpr_la_inst(riscv_reg_t gpr,bit use_label_as_imm=0, bit[31:0] imm_val=0, string label="");
      riscv_pseudo_instr pseudo_instr;
      pseudo_instr = riscv_pseudo_instr::type_id::create("pseudo_instr");

      `DV_CHECK_RANDOMIZE_WITH_FATAL(pseudo_instr,
          pseudo_instr_name == LA;
          rd == gpr;
      )
      if(use_label_as_imm) begin
          if(label.len() == 0) begin
            `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                        $sformatf("initialize_gpr_la_inst() have null label string for LA instr immediate"))
          end
          pseudo_instr.imm_str = $sformatf("%0s", label);
      end
      else begin
          pseudo_instr.imm_str = $sformatf("0x%0x", imm_val);
      end
      instr_list.push_back(pseudo_instr);

  endfunction : initialize_gpr_la_inst

  //Gen pseudo instruction LI to initialize gpr
  virtual function void initialize_gpr_li_inst(riscv_reg_t gpr, bit[31:0] imm_val=0);
      riscv_pseudo_instr pseudo_instr;
      pseudo_instr = riscv_pseudo_instr::type_id::create("pseudo_instr");

      `DV_CHECK_RANDOMIZE_WITH_FATAL(pseudo_instr,
         pseudo_instr_name == LI;
         rd == gpr;
      )
      pseudo_instr.imm_str = $sformatf("0x%0x", imm_val);
      instr_list.push_back(pseudo_instr);

  endfunction : initialize_gpr_li_inst

  //Main hwloop stream generation based on hwloop structure described
  virtual function void gen_xpulp_hwloop_control_instr();

      cv32e40p_instr        cv32_instr;
      bit                   hwloop_L;
      bit                   gen_cv_count0_instr;
      bit                   set_label_at_next_instr = 0;

      riscv_instr           hwloop_instr_list[$];
      int unsigned          num_rem_hwloop1_instr; //indicates num of hwloop_1 body instructions after  hwloop_0 body for nested hwloops
      string                label_s;
      string                start_label_s;
      string                end_label_s;

      num_instr_cv_start_to_loop_start_label[0] = num_fill_instr_loop_ctrl_to_loop_start[0] + 2;//TODO: can be randomized?
      num_instr_cv_start_to_loop_start_label[1] = num_fill_instr_loop_ctrl_to_loop_start[1] + 2;//TODO: can be randomized?

      set_label_at_next_instr = 0;

      //*************************************************************
      //*******************NESTED HWLOOP*****************************
      //*************************************************************

      if(gen_nested_loop) begin  //NESTED HWLOOP
          gen_cv_count0_instr = $urandom();

          //calculate num_rem_hwloop1_instr
          if(!setup_l0_before_l1_start) begin
            num_rem_hwloop1_instr = num_hwloop_instr[1] - (num_fill_instr_in_loop1_till_loop0_setup +
                                                           num_hwloop_ctrl_instr[0] +
                                                           num_fill_instr_loop_ctrl_to_loop_start[0] +
                                                           num_hwloop_instr[0]);
          end
          else begin
            num_rem_hwloop1_instr = num_hwloop_instr[1] - (num_fill_instr_in_loop1_till_loop0_setup +
                                                           1 +
                                                           num_fill_instr_loop_ctrl_to_loop_start[0] +
                                                           num_hwloop_instr[0]);

          end

          //Atleast 2 instructions needed between hwloop_0 and hwloop_1 end labels
          if(num_rem_hwloop1_instr < 2)
            `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",$sformatf("num_rem_hwloop1_instr < 2"))

          //Initialize GPRs used as RS1 in HWLOOP Instructions
          hwloop_avail_regs = new[6];  //index fixed for this stream from 0:2 for start0,end0,count0=setup0; 3:5 for start1,end1,count1=setup1 respectively
          std::randomize(hwloop_avail_regs) with  {   unique {hwloop_avail_regs};
                                                       foreach(hwloop_avail_regs[i]) {
                                                           !(hwloop_avail_regs[i] inside {ZERO, RA, SP, GP, TP});
                                                       }
                                                   };

          reserved_rd = hwloop_avail_regs;

          //start0
          label_s = $sformatf("hwloop0_nested_start_stream%0d",stream_count);
          initialize_gpr_la_inst(.gpr(hwloop_avail_regs[0]),.use_label_as_imm(1),.label(label_s));

          //end0
          label_s = $sformatf("hwloop0_nested_end_stream%0d",stream_count);
          initialize_gpr_la_inst(.gpr(hwloop_avail_regs[1]),.use_label_as_imm(1),.label(label_s));

          //count0
          initialize_gpr_li_inst(.gpr(hwloop_avail_regs[2]),.imm_val(hwloop_count[0]));

          //start1
          label_s = $sformatf("hwloop1_nested_start_stream%0d",stream_count);
          initialize_gpr_la_inst(.gpr(hwloop_avail_regs[3]),.use_label_as_imm(1),.label(label_s));

          //end1
          label_s = $sformatf("hwloop1_nested_end_stream%0d",stream_count);
          initialize_gpr_la_inst(.gpr(hwloop_avail_regs[4]),.use_label_as_imm(1),.label(label_s));

          //count1
          initialize_gpr_li_inst(.gpr(hwloop_avail_regs[5]),.imm_val(hwloop_count[1]));

          start_label_s = $sformatf("hwloop1_nested_start_stream%0d",stream_count);
          end_label_s = $sformatf("hwloop1_nested_end_stream%0d",stream_count);

          //set temp label here at 1st HWLOOP setup instr to be used to insert .align directive from sequence
          label_s = $sformatf("align_hwloop1_nested_control_stream%0d",stream_count);
          gen_hwloop_control_instr(.hwloop_L(1),
                                   .gen_cv_start_end_inst(1),
                                   .gen_cv_count_inst(1),
                                   .set_label_for_first_instr(1),
                                   .str_lbl_str(start_label_s),
                                   .end_lbl_str(end_label_s),
                                   .instr_label(label_s));  //Gen Outer HWLOOP Instr - 1

          reserved_rd.delete(); //no longer need to keep the hwloop1 reserved gprs
          reserved_rd = {hwloop_avail_regs[0],hwloop_avail_regs[1],hwloop_avail_regs[2]}; //preserve hwloop_0 reg for nested loop

          if(!use_setup_inst[1] && !use_setup_inst[0] && setup_l0_before_l1_start) begin

              start_label_s = $sformatf("hwloop0_nested_start_stream%0d",stream_count);
              end_label_s = $sformatf("hwloop0_nested_end_stream%0d",stream_count);
              gen_hwloop_control_instr(.hwloop_L(0),
                                       .gen_cv_start_end_inst(1),
                                       .gen_cv_count_inst(gen_cv_count0_instr),
                                       .set_label_for_first_instr(0),
                                       .str_lbl_str(start_label_s),
                                       .end_lbl_str(end_label_s),
                                       .instr_label(""));  //Gen Inner HWLOOP Instr- 0

              reserved_rd.delete(); //no longer need to keep the hwloop reserved gpr except for count0
              reserved_rd = {hwloop_avail_regs[2]}; //preserve count0 reg for nested loop

              if(num_fill_instr_loop_ctrl_to_loop_start[1] >= 2)
                  num_fill_instr_loop_ctrl_to_loop_start[1] = num_fill_instr_loop_ctrl_to_loop_start[1] - 2;

              if(gen_cv_count0_instr && num_fill_instr_loop_ctrl_to_loop_start[1] >= 1)
                  num_fill_instr_loop_ctrl_to_loop_start[1] = num_fill_instr_loop_ctrl_to_loop_start[1] - 1;
          end

          if(!use_setup_inst[1]) begin
              insert_rand_instr(.num_rand_instr(num_fill_instr_loop_ctrl_to_loop_start[1]),
                                .no_branch(1),
                                .no_compressed(0),
                                .no_fence(0));  //TODO: Fence instr allowed here?
          end
          else begin
              set_label_at_next_instr = 1; //no rand instr so next instruction must have a label
          end

          //LABEL HWLOOP1_NESTED_START:
          label_s = $sformatf("hwloop1_nested_start_stream%0d",stream_count);
          if(num_fill_instr_in_loop1_till_loop0_setup>0) begin
              insert_rand_instr_with_label(label_s,1);
              set_label_at_next_instr = 0; //reset flag

              num_fill_instr_in_loop1_till_loop0_setup = num_fill_instr_in_loop1_till_loop0_setup-1;

              if(num_fill_instr_in_loop1_till_loop0_setup>0)
                  insert_rand_instr(num_fill_instr_in_loop1_till_loop0_setup);
          end
          else begin
              set_label_at_next_instr = 1; //no fill instr so next instr must have label
          end

          start_label_s = $sformatf("hwloop0_nested_start_stream%0d",stream_count);
          end_label_s = $sformatf("hwloop0_nested_end_stream%0d",stream_count);

          if(!set_label_at_next_instr)
              gen_hwloop_control_instr(.hwloop_L(0),
                                       .gen_cv_start_end_inst(~setup_l0_before_l1_start),
                                       .gen_cv_count_inst(1),
                                       .set_label_for_first_instr(0),
                                       .str_lbl_str(start_label_s),
                                       .end_lbl_str(end_label_s),
                                       .instr_label(""));  //Gen Inner HWLOOP Instr- 0
          else
              gen_hwloop_control_instr(.hwloop_L(0),
                                       .gen_cv_start_end_inst(~setup_l0_before_l1_start),
                                       .gen_cv_count_inst(1),
                                       .set_label_for_first_instr(1),
                                       .str_lbl_str(start_label_s),
                                       .end_lbl_str(end_label_s),
                                       .instr_label(label_s));  //Gen Inner HWLOOP Instr- 0

          set_label_at_next_instr = 0; //reset flag

          //reserved_rd = {hwloop_avail_regs[2]}; //preserve count0 reg for nested loop

          if(!use_setup_inst[0])
              insert_rand_instr(num_fill_instr_loop_ctrl_to_loop_start[0]);

          //LABEL HWLOOP0_NESTED_START:
          label_s = $sformatf("hwloop0_nested_start_stream%0d",stream_count);
          insert_rand_instr_with_label(label_s,1);

          insert_rand_instr(num_hwloop_instr[0]-1);

          //LABEL HWLOOP0_NESTED_END:
          label_s = $sformatf("hwloop0_nested_end_stream%0d",stream_count);
          insert_rand_instr_with_label(label_s,1);

          insert_rand_instr(num_rem_hwloop1_instr-1);


          //LABEL HWLOOP1_NESTED_END:
          //Insert Some Random instructions
          //compressed instr allowed here
          reserved_rd.delete(); //hwloop nested body end so not required to keep the hwloop reserved gpr
          label_s = $sformatf("hwloop1_nested_end_stream%0d",stream_count);
          insert_rand_instr_with_label(.label_str(label_s),
                                       .label_is_pulp_hwloop_body_label(1),
                                       .no_branch(1),
                                       .no_compressed(0),
                                       .no_fence(0)); //TODO: Fence instr allowed here?

          insert_rand_instr(.num_rand_instr($urandom_range(0,20)),
                            .no_branch(1),
                            .no_compressed(0),
                            .no_fence(0));


      //*************************************************************
      //*******************NON-NESTED HWLOOPS************************
      //*************************************************************

      end else begin    //NON-NESTED HWLOOP
          for (int i=0; i< num_loops_active; i++) begin
              hwloop_L = $urandom_range(0,1);//use random hwloop id

              //Initialize GPRs used as RS1 in HWLOOP Instructions
              
              hwloop_avail_regs = new[6];  //index fixed for this stream from 0:2 for start0,end0,count0=setup0; 3:5 for start1,end1,count1=setup1 respectively
              std::randomize(hwloop_avail_regs) with  {   unique {hwloop_avail_regs};
                                                           foreach(hwloop_avail_regs[i]) {
                                                               !(hwloop_avail_regs[i] inside {ZERO, RA, SP, GP, TP});
                                                           }
                                                       };

              start_label_s = $sformatf("hwloop%0d_start_stream%0d_id%0d",hwloop_L,stream_count,i);
              end_label_s = $sformatf("hwloop%0d_end_stream%0d_id%0d",hwloop_L,stream_count,i);

              if(hwloop_L == 0) begin
                  //start0
                  initialize_gpr_la_inst(.gpr(hwloop_avail_regs[0]),.use_label_as_imm(1),.label(start_label_s));

                  //end0
                  initialize_gpr_la_inst(.gpr(hwloop_avail_regs[1]),.use_label_as_imm(1),.label(end_label_s));

                  //count0
                  initialize_gpr_li_inst(.gpr(hwloop_avail_regs[2]),.imm_val(hwloop_count[0]));
              end
              else begin
                  //start1
                  initialize_gpr_la_inst(.gpr(hwloop_avail_regs[3]),.use_label_as_imm(1),.label(start_label_s));

                  //end1
                  initialize_gpr_la_inst(.gpr(hwloop_avail_regs[4]),.use_label_as_imm(1),.label(end_label_s));

                  //count1
                  initialize_gpr_li_inst(.gpr(hwloop_avail_regs[5]),.imm_val(hwloop_count[1]));
              end

              //set temp label here at 1st HWLOOP setup instr to be used to insert .align directive from sequence
              label_s = $sformatf("align_hwloop%0d_control_stream%0d_id%0d",hwloop_L,stream_count,i);
              //<loop0/1_setup_instructions>  -> using start->end->count for this stream TODO: randomize this
              gen_hwloop_control_instr(.hwloop_L(hwloop_L),
                                       .gen_cv_start_end_inst(1),
                                       .gen_cv_count_inst(1),
                                       .set_label_for_first_instr(1),
                                       .str_lbl_str(start_label_s),
                                       .end_lbl_str(end_label_s),
                                       .instr_label(label_s));

              //Insert Random instructions till Loop HWLOOP_START0/1 label ->  use_setup_inst ? 0 : num_fill_instr_loop_ctrl_to_loop_start[0/1]
              if(!use_setup_inst[hwloop_L])
                  insert_rand_instr((num_fill_instr_loop_ctrl_to_loop_start[hwloop_L]),1,0,0);  // allow compressed instructions here ; TODO: Fence instr allowed here?

              //LABEL HWLOOP_START0/1:
              insert_rand_instr_with_label(start_label_s,1); // no branch, no compressed, no fence instructions inside hwloop

              //Insert Random instructions till Loop END0/1 label     ->  num_hwloop_instr[0/1]
              insert_rand_instr(num_hwloop_instr[hwloop_L]-1);  // no branch, no compressed, no fence instructions inside hwloop

              //LABEL HWLOOP_END0/1: Random instructions
              //compressed instr allowed here
              insert_rand_instr_with_label(.label_str(end_label_s),
                                           .label_is_pulp_hwloop_body_label(1),
                                           .no_branch(1),
                                           .no_compressed(0),
                                           .no_fence(0)); //TODO: Fence instr allowed here?

              //<Some more Random instructions>
              // allow compressed, fence instructions here
              insert_rand_instr(.num_rand_instr($urandom_range(0,30)),
                                .no_branch(1),
                                .no_compressed(0),
                                .no_fence(0));
          end
      end

  endfunction : gen_xpulp_hwloop_control_instr


  virtual function void gen_cv_setupi_instr(bit hwloop_L=0,bit use_str_uimmS=0,string str_uimmS="",bit add_label=0,string label_str="");
      bit[16:0] setupi_uimm;

      hwloop_setupi_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_setupi_instr_%0d", hwloop_L));
      hwloop_setupi_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_SETUPI));
      hwloop_setupi_instr[hwloop_L].hw_loop_label = hwloop_L;

      //randomize immediates
      setupi_uimm[11:0] = hwloop_counti[hwloop_L]; //same count value must be used for a give hwloop whether using setupi or counti
      setupi_uimm[16:12] = num_hwloop_instr[hwloop_L] + 1; //+ 1 reason: End addr of HWLoop must point to instr just after the last one of Loop body

      //with cv.setupi the loop must start immidiately after setup instruction so we dont need to have fill instructions here
      if(num_hwloop_instr[hwloop_L]>=31) 
          `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream", $sformatf("gen_cv_setupi_instr() cv_setupi uimmS value more than 30"))
      
      if(setupi_uimm[16:12] < 3)
          `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream", $sformatf("gen_cv_setupi_instr() cv_setupi uimmS value less than 3"))
          //setupi_uimm[16:12] = 3;  //HWLoop body must contain at least 3 instructions
      
      hwloop_setupi_instr[hwloop_L].imm = setupi_uimm;
      hwloop_setupi_instr[hwloop_L].extend_imm();

      if(use_str_uimmS) begin
          if(str_uimmS.len() == 0) begin
              `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                          $sformatf("gen_cv_setupi_instr() have null uimmS string for CV_SETUPI instr immediate"))
          end
          hwloop_setupi_instr[hwloop_L].imm_str = $sformatf("%0d, %0s",$unsigned(setupi_uimm[11:0]),str_uimmS);
      end
      else begin
          hwloop_setupi_instr[hwloop_L].update_imm_str();
      end

      hwloop_setupi_instr[hwloop_L].has_label = add_label;
      hwloop_setupi_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_setupi_instr

  virtual function void gen_cv_setup_instr(bit hwloop_L=0,
                                           bit use_str_uimmL=0,
                                           string str_uimmL="",
                                           bit add_label=0,
                                           string label_str="");

      bit[11:0] setup_uimmL;

      hwloop_setup_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_setup_instr_%0d", hwloop_L));
      hwloop_setup_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_SETUP));
      hwloop_setup_instr[hwloop_L].hw_loop_label = hwloop_L;

      //randomize immediates
      //with cv.setup the loop must start immidiately after setup instruction so we dont need to have fill instructions here
      setup_uimmL = num_hwloop_instr[hwloop_L] + 1; //+ 1 : End addr of HWLoop point to instr just after the last one of Loop body

      hwloop_setup_instr[hwloop_L].imm = setup_uimmL;
      hwloop_setup_instr[hwloop_L].extend_imm();

      if(use_str_uimmL) begin
          if(str_uimmL.len() == 0) begin
              `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                          $sformatf("gen_cv_setup_instr() have null uimmL string for CV_SETUP instr immediate"))
          end
          hwloop_setup_instr[hwloop_L].imm_str = $sformatf("%0s", str_uimmL);
      end
      else begin
          hwloop_setup_instr[hwloop_L].update_imm_str();
      end
      hwloop_setup_instr[hwloop_L].has_label = add_label;
      hwloop_setup_instr[hwloop_L].label = label_str;

      //get randomized GPR
      hwloop_setup_instr[hwloop_L].rs1 = hwloop_avail_regs[(hwloop_L*3) + 2];

  endfunction : gen_cv_setup_instr

  virtual function void gen_cv_starti_instr(bit hwloop_L=0,
                                            bit use_str_uimmL=0,
                                            string str_uimmL="",
                                            bit add_label=0,
                                            string label_str="");

      bit[11:0] starti_uimmL;

      hwloop_starti_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_starti_instr_%0d", hwloop_L));
      hwloop_starti_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_STARTI));
      hwloop_starti_instr[hwloop_L].hw_loop_label = hwloop_L;

      //randomize immediates
      starti_uimmL = num_instr_cv_start_to_loop_start_label[hwloop_L] + 1;
      hwloop_starti_instr[hwloop_L].imm = starti_uimmL;
      hwloop_starti_instr[hwloop_L].extend_imm();

      if(use_str_uimmL) begin
          if(str_uimmL.len() == 0) begin
              `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                         $sformatf("gen_cv_starti_instr() have null uimmL string for CV_STARTI instr immediate"))
          end
          hwloop_starti_instr[hwloop_L].imm_str = $sformatf("%0s", str_uimmL);
      end
      else begin
          hwloop_starti_instr[hwloop_L].update_imm_str();
      end
      hwloop_starti_instr[hwloop_L].has_label = add_label;
      hwloop_starti_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_starti_instr

  virtual function void gen_cv_start_instr(bit hwloop_L=0,bit add_label=0,string label_str="");

      hwloop_start_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_start_instr_%0d", hwloop_L));
      hwloop_start_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_START));
      hwloop_start_instr[hwloop_L].hw_loop_label = hwloop_L;

      //rs1 = hwloop_start[hwloop_L];
      //get randomized GPR
      hwloop_start_instr[hwloop_L].rs1 = hwloop_avail_regs[(hwloop_L*3) + 0];
      hwloop_start_instr[hwloop_L].has_label = add_label;
      hwloop_start_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_start_instr

  virtual function void gen_cv_endi_instr(bit hwloop_L=0,
                                          bit use_str_uimmL=0,
                                          string str_uimmL="",
                                          bit add_label=0,
                                          string label_str="");

      bit[11:0] endi_uimmL;

      hwloop_endi_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_endi_instr_%0d", hwloop_L));
      hwloop_endi_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_ENDI));
      hwloop_endi_instr[hwloop_L].hw_loop_label = hwloop_L;

      //randomize immediates
      //TODO: check : while using cv_endi there is possiblity of some other instr before loop start
      //thats why using a count for such fill instructions

      //add 1 to imm - for cv.count instuction after cv.endi instr
      //add 1 to imm - End addr of an HWLoop must point to the instr just after the last one of the HWLoop body
      endi_uimmL = 1 + num_fill_instr_loop_ctrl_to_loop_start[hwloop_L] + num_hwloop_instr[hwloop_L] + 1;

      hwloop_endi_instr[hwloop_L].imm = endi_uimmL;
      hwloop_endi_instr[hwloop_L].extend_imm();

      if(use_str_uimmL) begin
        if(str_uimmL.len() == 0) begin
            `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                        $sformatf("gen_cv_endi_instr() have null uimmL string for CV_ENDI instr immediate"))
        end
        hwloop_endi_instr[hwloop_L].imm_str = $sformatf("%0s", str_uimmL);
      end
      else begin
        hwloop_endi_instr[hwloop_L].update_imm_str();
      end
      hwloop_endi_instr[hwloop_L].has_label = add_label;
      hwloop_endi_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_endi_instr

  virtual function void gen_cv_end_instr(bit hwloop_L=0,bit add_label=0,string label_str="");

      hwloop_end_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_end_instr_%0d", hwloop_L));
      hwloop_end_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_END));
      hwloop_end_instr[hwloop_L].hw_loop_label = hwloop_L;

      //rs1 = hwloop_end[hwloop_L];
      //get randomized GPR
      hwloop_end_instr[hwloop_L].rs1 = hwloop_avail_regs[(hwloop_L*3) + 1];
      hwloop_end_instr[hwloop_L].has_label = add_label;
      hwloop_end_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_end_instr


  virtual function void gen_cv_counti_instr(bit hwloop_L=0,bit add_label=0,string label_str="");

      bit[11:0] counti_uimmL;

      hwloop_counti_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_counti_instr_%0d", hwloop_L));
      hwloop_counti_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_COUNTI));
      hwloop_counti_instr[hwloop_L].hw_loop_label = hwloop_L;

      //randomize immediates
      counti_uimmL = hwloop_counti[hwloop_L];
      //std::randomize(hwloop_counti_instr[hwloop_L].imm) with {hwloop_counti_instr[hwloop_L].imm == counti_uimmL;};
      hwloop_counti_instr[hwloop_L].imm = counti_uimmL;
      hwloop_counti_instr[hwloop_L].extend_imm();
      hwloop_counti_instr[hwloop_L].update_imm_str();
      hwloop_counti_instr[hwloop_L].has_label = add_label;
      hwloop_counti_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_counti_instr

  virtual function void gen_cv_count_instr(bit hwloop_L=0,bit add_label=0,string label_str="");

      hwloop_count_instr[hwloop_L] = cv32e40p_instr::type_id::create($sformatf("hwloop_count_instr_%0d", hwloop_L));
      hwloop_count_instr[hwloop_L] = cv32e40p_instr::get_cv32e40p_instr(.name(CV_COUNT));
      hwloop_count_instr[hwloop_L].hw_loop_label = hwloop_L;

      //rs1 = hwloop_count[hwloop_L];
      //get randomized GPR
      hwloop_count_instr[hwloop_L].rs1 = hwloop_avail_regs[(hwloop_L*3) + 2];
      hwloop_count_instr[hwloop_L].has_label = add_label;
      hwloop_count_instr[hwloop_L].label = label_str;

  endfunction : gen_cv_count_instr


  virtual function void gen_hwloop_control_instr(bit hwloop_L=0,
                                                 bit gen_cv_start_end_inst=1,
                                                 bit gen_cv_count_inst=1,
                                                 bit set_label_for_first_instr=0,
                                                 string str_lbl_str="",
                                                 string end_lbl_str="",
                                                 string instr_label="");

      int order_count = 0;
      bit set_label = 0;

      if(use_setup_inst[hwloop_L]) begin //HWLOOP with CV.SETUP/I instruction
          if(use_loop_setupi_inst[hwloop_L]) begin
              gen_cv_setupi_instr(.hwloop_L(hwloop_L),
                                  .use_str_uimmS(1),
                                  .str_uimmS(end_lbl_str),
                                  .add_label(set_label_for_first_instr),
                                  .label_str(instr_label));

              instr_list.push_back(hwloop_setupi_instr[hwloop_L]);
          end
          else begin
              gen_cv_setup_instr(.hwloop_L(hwloop_L),
                                 .use_str_uimmL(1),
                                 .str_uimmL(end_lbl_str),
                                 .add_label(set_label_for_first_instr),
                                 .label_str(instr_label));

              instr_list.push_back(hwloop_setup_instr[hwloop_L]);
          end
      end
      else begin //HWLOOP CV.START/I,CV.END/I,CV.COUNT/I instructions
          if(gen_cv_start_end_inst) begin
              set_label = set_label_for_first_instr;
               //(1) Gen CV_START/I instruction
              if(use_loop_starti_inst[hwloop_L]) begin
                  gen_cv_starti_instr(.hwloop_L(hwloop_L),
                                      .use_str_uimmL(1),
                                      .str_uimmL(str_lbl_str),
                                      .add_label(set_label),
                                      .label_str(instr_label));

                  instr_list.push_back(hwloop_starti_instr[hwloop_L]);
              end
              else begin
                  gen_cv_start_instr(.hwloop_L(hwloop_L),
                                     .add_label(set_label),
                                     .label_str(instr_label));

                  instr_list.push_back(hwloop_start_instr[hwloop_L]);
              end
              order_count++;

               //(2) Gen CV_END/I instruction ;
               //TODO:No label added as this order is not randomized 
              if(use_loop_endi_inst[hwloop_L]) begin
                  gen_cv_endi_instr(.hwloop_L(hwloop_L),
                                    .use_str_uimmL(1),
                                    .str_uimmL(end_lbl_str),
                                    .add_label(0),
                                    .label_str(""));

                  instr_list.push_back(hwloop_endi_instr[hwloop_L]);
              end
              else begin
                  gen_cv_end_instr(.hwloop_L(hwloop_L),.add_label(0),.label_str(""));
                  instr_list.push_back(hwloop_end_instr[hwloop_L]);
              end
              order_count++;
          end

          if(gen_cv_count_inst) begin
              set_label = (order_count == 0) ? set_label_for_first_instr : 0;
               //(3) Gen CV_COUNT/I instruction
              if(use_loop_counti_inst[hwloop_L]) begin
                  gen_cv_counti_instr(.hwloop_L(hwloop_L),.add_label(set_label),.label_str(instr_label));
                  instr_list.push_back(hwloop_counti_instr[hwloop_L]);
              end
              else begin
                  gen_cv_count_instr(.hwloop_L(hwloop_L),.add_label(set_label),.label_str(instr_label));
                  instr_list.push_back(hwloop_count_instr[hwloop_L]);
              end
          end
      end
  endfunction : gen_hwloop_control_instr

  virtual function void insert_rand_instr(int unsigned num_rand_instr,
                                          bit no_branch=1,
                                          bit no_compressed=1,
                                          bit no_fence=1);

      riscv_instr instr;
      int unsigned i;

      //use cfg for ebreak
      if(cfg.no_ebreak)
          riscv_exclude_instr = {riscv_exclude_instr, EBREAK, C_EBREAK};

      if(no_branch)
          riscv_exclude_instr = {riscv_exclude_instr, BEQ, BNE, BLT, BGE, BLTU, BGEU, C_BEQZ, C_BNEZ};

      if(no_compressed)
          riscv_exclude_group = {riscv_exclude_group, RV32C};

      if(no_fence)
          riscv_exclude_instr = {riscv_exclude_instr, FENCE, FENCE_I};

      `uvm_info("cv32e40p_xpulp_hwloop_base_stream",
                 $sformatf("insert_rand_instr- Number of Random instr to generate= %0d",num_rand_instr),
                 UVM_HIGH)

      if(num_rand_instr > MAX_HWLOOP_INSTR_GEN) begin
          `uvm_fatal("cv32e40p_xpulp_hwloop_base_stream",
                      $sformatf("Too many hwloop instr. num_rand_instr = %0d",num_rand_instr))
      end

      i = 0;
      while (i < num_rand_instr) begin
          //Create and Randomize array for avail_regs each time to ensure randomization
          avail_regs = new[num_of_avail_regs - reserved_rd.size()];
          randomize_avail_regs();

          instr = riscv_instr::type_id::create($sformatf("instr_%0d", i));
          instr = riscv_instr::get_rand_instr(.exclude_instr(riscv_exclude_instr),
                                              .exclude_group(riscv_exclude_group));

          //randomize GPRs for each instruction
          randomize_gpr(instr);

          //randomize immediates for each instruction
          randomize_riscv_instr_imm(instr);

          instr_list.push_back(instr);
          i++;
      end

  endfunction

  virtual function void insert_rand_instr_with_label(string label_str,
                                                     bit label_is_pulp_hwloop_body_label=0,
                                                     bit no_branch=1,
                                                     bit no_compressed=1,
                                                     bit no_fence=1);
      riscv_instr instr;
      cv32e40p_instr cv32_instr;

      //use cfg for ebreak
      if(cfg.no_ebreak)
          riscv_exclude_instr = {riscv_exclude_instr, EBREAK, C_EBREAK};

      if(no_branch)
          riscv_exclude_instr = {riscv_exclude_instr, BEQ, BNE, BLT, BGE, BLTU, BGEU, C_BEQZ, C_BNEZ};

      if(no_compressed)
          riscv_exclude_group = {riscv_exclude_group, RV32C};

      if(no_fence)
          riscv_exclude_instr = {riscv_exclude_instr, FENCE, FENCE_I};

      //Create and Randomize array for avail_regs each time to ensure randomization
      avail_regs = new[num_of_avail_regs];
      randomize_avail_regs();

      instr = riscv_instr::type_id::create($sformatf("instr_%0s", label_str));
      instr = riscv_instr::get_rand_instr(.exclude_instr(riscv_exclude_instr),
                                          .exclude_group(riscv_exclude_group));

      //randomize GPRs for each instruction
      randomize_gpr(instr);
      //randomize immediates for each instruction
      randomize_riscv_instr_imm(instr);
      instr.has_label=1;
      instr.label = label_str;
      instr_list.push_back(instr);

  endfunction

endclass : cv32e40p_xpulp_hwloop_base_stream

//Class: cv32e40p_xpulp_short_hwloop_stream
//Running with <= 20 instructions in HWLOOP
//Increase Loop Count range to excersize upto 4095 (12-bit) uimmL value
class cv32e40p_xpulp_short_hwloop_stream extends cv32e40p_xpulp_hwloop_base_stream;

  rand bit              loop0_high_count;

  `uvm_object_utils_begin(cv32e40p_xpulp_short_hwloop_stream)
      `uvm_field_int(num_loops_active, UVM_DEFAULT)
      `uvm_field_int(gen_nested_loop, UVM_DEFAULT)
      `uvm_field_sarray_int(use_setup_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_counti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_starti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_endi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_setupi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_count, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_counti, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_ctrl_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_fill_instr_loop_ctrl_to_loop_start, UVM_DEFAULT)
      `uvm_field_int(num_fill_instr_in_loop1_till_loop0_setup, UVM_DEFAULT)
      `uvm_field_int(setup_l0_before_l1_start, UVM_DEFAULT)
      `uvm_field_sarray_int(num_instr_cv_start_to_loop_start_label, UVM_DEFAULT)
      `uvm_field_int(loop0_high_count, UVM_DEFAULT)
  `uvm_object_utils_end

  constraint gen_hwloop_count_c {

      solve gen_nested_loop, loop0_high_count before hwloop_count, hwloop_counti;
      solve gen_nested_loop before loop0_high_count;

      num_loops_active inside {1};

      if(gen_nested_loop) {
        if(loop0_high_count) {
          hwloop_counti[0] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                 [2048:4095] := 50, 4095 := 300};

          hwloop_count[0] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                [2048:4094] := 50, 4095 := 300};

          hwloop_counti[1] inside {[0:5]};
          hwloop_count[1] inside {[0:5]};

        } else {
          hwloop_counti[0] inside {[0:5]};
          hwloop_count[0] inside {[0:5]};

          hwloop_counti[1] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                 [2048:4095] := 50, 4095 := 300};

          hwloop_count[1] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                [2048:4094] := 50, 4095 := 300};
        }


      } else {
        foreach(hwloop_counti[i])
          hwloop_counti[i] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                 [2048:4095] := 50, 4095 := 300}; //TODO: check 0 is valid

        //TODO: for rs1 32 bit count ?
        foreach(hwloop_count[i])
          hwloop_count[i] dist {[0:400] := 10, [401:1023] := 300, [1024:2047] := 150,
                                [2048:4094] := 50, 4095 := 300};//TODO: check 0 is valid
      }
  }


  constraint num_hwloop_instr_c {
      solve num_hwloop_instr[0] before num_hwloop_instr[1];

      solve num_hwloop_instr[1] before num_fill_instr_in_loop1_till_loop0_setup,
                                       num_fill_instr_loop_ctrl_to_loop_start[0];

      solve use_loop_setupi_inst[1] before use_loop_setupi_inst[0];

      solve num_hwloop_ctrl_instr before num_hwloop_instr;

      solve gen_nested_loop, setup_l0_before_l1_start, use_setup_inst before num_hwloop_instr,
                                                                             num_fill_instr_loop_ctrl_to_loop_start,
                                                                             num_fill_instr_in_loop1_till_loop0_setup,
                                                                             num_hwloop_ctrl_instr;

      solve gen_nested_loop, setup_l0_before_l1_start before use_setup_inst,
                                                             use_loop_setupi_inst;

      solve gen_nested_loop before setup_l0_before_l1_start;


      setup_l0_before_l1_start dist {0 := 80, 1 := 20};

      if ((gen_nested_loop == 1) && (setup_l0_before_l1_start == 1)) {
          use_setup_inst[0] == 0;
          use_setup_inst[1] == 0;
          use_loop_setupi_inst[0] == 0;
          use_loop_setupi_inst[1] == 0;
      }

      if(use_setup_inst[0]) {
          num_fill_instr_loop_ctrl_to_loop_start[0] == 0;
          num_hwloop_ctrl_instr[0] == 1;
      } else {
          num_fill_instr_loop_ctrl_to_loop_start[0] inside {[0:3]};
          num_hwloop_ctrl_instr[0] == 3;
      }

      if(use_setup_inst[1]) {
          num_fill_instr_loop_ctrl_to_loop_start[1] == 0;
          num_hwloop_ctrl_instr[1] == 1;
      } else {
          num_fill_instr_loop_ctrl_to_loop_start[1] inside {[0:3]};
          num_hwloop_ctrl_instr[1] == 3;
      }

      if (gen_nested_loop == 1) {
          if (setup_l0_before_l1_start == 1) {
            num_hwloop_instr[0] inside {[3:17]};
            num_hwloop_instr[1] >= num_hwloop_instr[0] + 1 + 2; // 1 for cv.count0 ; 2 for end of loop req
            num_hwloop_instr[1] <= 19 + 1; // 1 for cv.count0
            num_fill_instr_in_loop1_till_loop0_setup inside {[0:5]};
            (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - 1); // 1 for cv.count0
          } else {
            if (use_setup_inst[1] && use_loop_setupi_inst[1] && ~use_setup_inst[0]) { //with setupi only [4:0] uimmS range avail for end label
                  num_hwloop_instr[0] inside {[3:15]};
            } else {
                num_hwloop_instr[0] inside {[3:17]};
            }
            num_hwloop_instr[1] >= num_hwloop_instr[0] + num_hwloop_ctrl_instr[0] + 2;
            num_hwloop_instr[1] <= 20;
            num_fill_instr_in_loop1_till_loop0_setup inside {[0:4]};
            (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - num_hwloop_ctrl_instr[0]);
          }
      } else {
          num_hwloop_instr[1] inside {[3:20]};
          num_hwloop_instr[0] inside {[3:20]};
          num_fill_instr_in_loop1_till_loop0_setup == 0;
      }
  }

  function new(string name = "cv32e40p_xpulp_short_hwloop_stream");
      super.new(name);
  endfunction : new

  function void pre_randomize();
      super.pre_randomize();
  endfunction : pre_randomize

  function void post_randomize();
      super.post_randomize();
      this.print();
  endfunction : post_randomize

endclass : cv32e40p_xpulp_short_hwloop_stream


//Class: cv32e40p_xpulp_long_hwloop_stream
//Running with large instruction number in HWLOOP upto 4094 corresponding to 12-bit uimmL for end label.
//Max num inside HWLOOP body can be 4094 only as End label is on instruction after last instr of HWLOOP.
//Reduce Loop Count range to upto 50.
class cv32e40p_xpulp_long_hwloop_stream extends cv32e40p_xpulp_hwloop_base_stream;

  `uvm_object_utils_begin(cv32e40p_xpulp_long_hwloop_stream)
      `uvm_field_int(num_loops_active, UVM_DEFAULT)
      `uvm_field_int(gen_nested_loop, UVM_DEFAULT)
      `uvm_field_sarray_int(use_setup_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_counti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_starti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_endi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_setupi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_count, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_counti, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_ctrl_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_fill_instr_loop_ctrl_to_loop_start, UVM_DEFAULT)
      `uvm_field_int(num_fill_instr_in_loop1_till_loop0_setup, UVM_DEFAULT)
      `uvm_field_int(setup_l0_before_l1_start, UVM_DEFAULT)
      `uvm_field_sarray_int(num_instr_cv_start_to_loop_start_label, UVM_DEFAULT)
  `uvm_object_utils_end

  constraint gen_hwloop_count_c {
      num_loops_active inside {1};
      foreach(hwloop_counti[i])
          hwloop_counti[i] inside {[0:50]};//TODO: check 0 is valid

      foreach(hwloop_count[i])
          hwloop_count[i] inside {[0:50]};//TODO: check 0 is valid
  }


  constraint num_hwloop_instr_c {
      solve num_hwloop_instr[0] before num_hwloop_instr[1];

      solve num_hwloop_instr[1] before num_fill_instr_in_loop1_till_loop0_setup,
                                       num_fill_instr_loop_ctrl_to_loop_start[0];

      solve use_loop_setupi_inst[1] before use_loop_setupi_inst[0];

      solve num_hwloop_ctrl_instr before num_hwloop_instr;

      solve gen_nested_loop, setup_l0_before_l1_start, use_setup_inst before num_hwloop_instr,
                                                                             num_fill_instr_loop_ctrl_to_loop_start,
                                                                             num_fill_instr_in_loop1_till_loop0_setup,
                                                                             num_hwloop_ctrl_instr;

      solve gen_nested_loop, setup_l0_before_l1_start before use_setup_inst,
                                                             use_loop_setupi_inst;

      solve gen_nested_loop before setup_l0_before_l1_start;


      setup_l0_before_l1_start dist {0 := 80, 1 := 20};

      if ((gen_nested_loop == 1) && (setup_l0_before_l1_start == 1)) {
          use_setup_inst[0] == 0;
          use_setup_inst[1] == 0;
          use_loop_setupi_inst[0] == 0;
      }

      if (gen_nested_loop == 0) {
          use_loop_setupi_inst[0] == 0; //we don't want this case again in long hwloop stream
      }

      use_loop_setupi_inst[1] == 0; //we don't want this case again in long hwloop stream

      if(use_setup_inst[0]) {
          num_fill_instr_loop_ctrl_to_loop_start[0] == 0;
          num_hwloop_ctrl_instr[0] == 1;
      } else {
          num_fill_instr_loop_ctrl_to_loop_start[0] inside {[0:200]};
          num_hwloop_ctrl_instr[0] == 3;
      }

      if(use_setup_inst[1]) {
          num_fill_instr_loop_ctrl_to_loop_start[1] == 0;
          num_hwloop_ctrl_instr[1] == 1;
      } else {
          //num_fill_instr_loop_ctrl_to_loop_start[1] inside {[0:200]};
          num_fill_instr_loop_ctrl_to_loop_start[1] == 0; // For this long test non-zero value here is not necessary
          num_hwloop_ctrl_instr[1] == 3;
      }

      if (gen_nested_loop == 1) {
          if (setup_l0_before_l1_start == 1) {
              num_hwloop_instr[0] inside {[3:4082]};
              num_hwloop_instr[1] >= num_hwloop_instr[0] + 1 + 2; // 1 for cv.count0 ; 2 for end of loop req
              num_hwloop_instr[1] <= 4085; // Max can be 4094 only as end label is on instruction after last instr of HWLOOP
              num_fill_instr_in_loop1_till_loop0_setup inside {[0:800]};
              (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - 1); // 1 for cv.count0
          } else {
              if (use_setup_inst[0]) {
                  if (use_loop_setupi_inst[0]) {
                      num_hwloop_instr[0] inside {[3:30]};
                  } else {
                      num_hwloop_instr[0] inside {[3:4082]};
                  }
              } else {
                  num_hwloop_instr[0] inside {[3:4080]};
              }
              num_hwloop_instr[1] >= num_hwloop_instr[0] + num_hwloop_ctrl_instr[0] + 2; // 2 for end of loop req
              num_hwloop_instr[1] <= 4085; // Max can be 4094 only as end label is on instruction after last instr of HWLOOP
              num_fill_instr_in_loop1_till_loop0_setup inside {[0:800]};
              (num_fill_instr_loop_ctrl_to_loop_start[0] + num_fill_instr_in_loop1_till_loop0_setup) <= (num_hwloop_instr[1] - num_hwloop_instr[0] - 2 - num_hwloop_ctrl_instr[0]);
          }
      } else {
          num_hwloop_instr[1] inside {[3:4085]}; // Max can be 4094 only as end label is on instruction after last instr of HWLOOP
          num_hwloop_instr[0] inside {[3:4085]}; // Max can be 4094 only as end label is on instruction after last instr of HWLOOP
          num_fill_instr_in_loop1_till_loop0_setup == 0;
      }
  }

  function new(string name = "cv32e40p_xpulp_long_hwloop_stream");
      super.new(name);
  endfunction : new

  function void pre_randomize();
      super.pre_randomize();
  endfunction : pre_randomize

  function void post_randomize();
      super.post_randomize();
      this.print();
  endfunction : post_randomize

endclass : cv32e40p_xpulp_long_hwloop_stream

//Class: cv32e40p_xpulp_hwloop_isa_stress_stream
//Hwloop stream with more randomized instr categories and groups
//to focus on running more combinations inside hwloop
class cv32e40p_xpulp_hwloop_isa_stress_stream extends cv32e40p_xpulp_hwloop_base_stream;

  rand riscv_instr_category_t   rand_exclude_category[];
  rand bit                      exclude_floating_pt_instr;

  `uvm_object_utils_begin(cv32e40p_xpulp_hwloop_isa_stress_stream)
      `uvm_field_int(num_loops_active, UVM_DEFAULT)
      `uvm_field_int(gen_nested_loop, UVM_DEFAULT)
      `uvm_field_sarray_int(use_setup_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_counti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_starti_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_endi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(use_loop_setupi_inst, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_count, UVM_DEFAULT)
      `uvm_field_sarray_int(hwloop_counti, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_hwloop_ctrl_instr, UVM_DEFAULT)
      `uvm_field_sarray_int(num_fill_instr_loop_ctrl_to_loop_start, UVM_DEFAULT)
      `uvm_field_int(num_fill_instr_in_loop1_till_loop0_setup, UVM_DEFAULT)
      `uvm_field_int(setup_l0_before_l1_start, UVM_DEFAULT)
      `uvm_field_sarray_int(num_instr_cv_start_to_loop_start_label, UVM_DEFAULT)
      `uvm_field_int(exclude_floating_pt_instr, UVM_DEFAULT)
      `uvm_field_sarray_enum(riscv_instr_category_t,rand_exclude_category, UVM_DEFAULT)
  `uvm_object_utils_end

  constraint excl_f_inst_c {
      exclude_floating_pt_instr dist {0 := 90, 1 := 10};
  }

  constraint exc_category_c {
      rand_exclude_category.size() inside {[4:6]};
      unique {rand_exclude_category};
      foreach(rand_exclude_category[i]) {
          rand_exclude_category[i] dist { SIMD := 80,MAC := 75,
                                          BITMANIP := 70,ALU := 60,
                                          POST_INC_LOAD := 30,POST_INC_STORE := 30,
                                          ARITHMETIC := 5,LOGICAL := 5
                                        };
      }
  }


  function new(string name = "cv32e40p_xpulp_hwloop_isa_stress_stream");
      super.new(name);
  endfunction : new

  function void pre_randomize();
      super.pre_randomize();
  endfunction : pre_randomize

  function void post_randomize();
      cv32e40p_exclude_regs = {cv32e40p_exclude_regs,cv32e40p_reserved_regs};
      super.post_randomize();
      this.print();
  endfunction : post_randomize

  virtual function void insert_rand_instr(int unsigned num_rand_instr,
                                          bit no_branch=1,
                                          bit no_compressed=1,
                                          bit no_fence=1);

      riscv_instr         instr;
      cv32e40p_instr      cv32_instr;
      int unsigned i;

      //use cfg for ebreak
      if(cfg.no_ebreak)
          riscv_exclude_instr = {riscv_exclude_instr, EBREAK, C_EBREAK};

      if(no_branch)
          riscv_exclude_instr = {riscv_exclude_instr, BEQ, BNE, BLT, BGE, BLTU, BGEU, C_BEQZ, C_BNEZ};

      if(no_compressed)
          riscv_exclude_group = {riscv_exclude_group, RV32C};

      if(no_fence)
          riscv_exclude_instr = {riscv_exclude_instr, FENCE, FENCE_I};

      if(exclude_floating_pt_instr)
          riscv_exclude_group = {riscv_exclude_group, RV32F, RV32ZFINX};

      `uvm_info("cv32e40p_xpulp_hwloop_isa_stress_stream",
                 $sformatf("Insert_rand_instr- Number of Random instr to generate = %0d",num_rand_instr),
                 UVM_HIGH)

      if(num_rand_instr > MAX_HWLOOP_INSTR_GEN) begin
          `uvm_fatal("cv32e40p_xpulp_hwloop_isa_stress_stream",
                      $sformatf("Too many hwloop instr. num_rand_instr = %0d",num_rand_instr))
      end

      i = 0;
      while (i < num_rand_instr) begin
          //Create and Randomize array for avail_regs each time to ensure randomization
          avail_regs = new[num_of_avail_regs];
          randomize_avail_regs();

          cv32e40p_avail_regs = new[num_of_avail_regs];
          std::randomize(cv32e40p_avail_regs) with {  foreach(cv32e40p_avail_regs[i]) {
                                                        !(cv32e40p_avail_regs[i] inside {cv32e40p_exclude_regs});
                                                   }
                                                };

          instr = riscv_instr::type_id::create();
          cv32_instr = cv32e40p_instr::type_id::create();
          instr = riscv_instr::get_rand_instr(.exclude_instr(riscv_exclude_instr),
                                              .exclude_category(rand_exclude_category),
                                              .exclude_group(riscv_exclude_group));

          //randomize GPRs and immediates for each instruction
          if(instr.group != RV32X) begin
            randomize_gpr(instr);
            randomize_riscv_instr_imm(instr);
            instr_list.push_back(instr);
          end
          else begin
            $cast(cv32_instr,instr);
            randomize_cv32e40p_gpr(cv32_instr, cv32e40p_avail_regs);
            randomize_cv32e40p_instr_imm(cv32_instr);
            instr_list.push_back(cv32_instr);
          end
          i++;
      end

  endfunction
endclass : cv32e40p_xpulp_hwloop_isa_stress_stream
