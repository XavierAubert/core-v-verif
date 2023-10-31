// Copyright 2020 ETH Zurich
// Copyright 2020 OpenHW Group
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
// 
// Description : Cycle through fp instrs and checks mstatus transision from Initial or Clean to Dirty state
// 

#include <stdio.h>

#define MSTATUS_FS_INITIAL  0x00002000
#define MSTATUS_FS_CLEAN    0x00004000

#define MSTATUS_EXP_DIRTY   0x80007800
#define MSTATUS_EXP_INITIAL 0x00003800
#define MSTATUS_EXP_CLEAN   0x00005800
#define MSTATUS_EXP_ZFINX   0x00001800

volatile unsigned int error = 0;

void set_MSTATUS_n_check_FS (unsigned int val) {
  unsigned int fs = val;
  __asm__ volatile("csrw mstatus, %0;"
                   : : "r"(fs));
  if (val == MSTATUS_FS_INITIAL) {
    get_MSTATUS_n_check_FS(MSTATUS_EXP_INITIAL);
  }
  if (val == MSTATUS_FS_CLEAN) {
    get_MSTATUS_n_check_FS(MSTATUS_EXP_CLEAN);
  }
}

void get_MSTATUS_n_check_FS (unsigned int expected) {
  unsigned int rd_mstatus;
  __asm__ volatile("csrr %0, mstatus" : "=r"(rd_mstatus));
#ifdef ZFINX
 expected = MSTATUS_EXP_ZFINX;
#endif
  if (rd_mstatus != expected) {
    printf("[get_MSTATUS_n_check_FS] FS mismatched -> received[0x%8x] : expected[0x%8x] \n", rd_mstatus, expected);
    error++;
  } else {
    // printf("[get_MSTATUS_n_check_FS] FS matached   -> received[0x%8x] : expected[0x%8x] \n", rd_mstatus, expected); 
  }
}

int main()
{

#ifdef ZFINX 
  set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile("fle.s                t1, s5, s1");            printf("-- fle --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fsqrt.s              s1, s6");                printf("-- fsqrt --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fmsub.s              s3, s2, s1, s1#0");      printf("-- fmsub --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fmul.s               a1, a3, s5, rne");       printf("-- fmul --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("flt.s                s4, t4, s5");            printf("-- flt --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("feq.s                s10, a3, s6");           printf("-- feq --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fnmadd.s             t4, s3, s6, s11");       printf("-- fnmadd --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fsub.s               t2, a1, s6");            printf("-- fsub --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fsgnj.s              s3, s0, s5");            printf("-- fsgnj --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fnmsub.s             a3, ra, s3, zero");      printf("-- fnmsub --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fcvt.s.wu            t6, a4");                printf("-- fcvt.s.wu --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fcvt.wu.s            t2, s1, rdn");           printf("-- fcvt.wu.s --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fcvt.s.w             a0, a4");                printf("-- fcvt.s.w --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fmadd.s              t4, t2, s1, a1, rdn");   printf("-- fmadd --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fsgnjx.s             ra, a1, a1");            printf("-- fsgnjx --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fadd.s               t4, s1, s11, rmm");      printf("-- fadd --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fmin.s               t1, t2, t2");            printf("-- fmin --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fdiv.s               t2, t2, s10");           printf("-- fdiv --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fcvt.w.s             t3, t2");                printf("-- fcvt.w.s --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fmax.s               t6, a4, a0");            printf("-- fmax --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fsgnjn.s             a1, a0, a4");            printf("-- fsgnjn --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
  __asm__ volatile("fclass.s             a0, s11");               printf("-- fclass --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_ZFINX);
#else
  // CLEAN -> DIRTY
  set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmul.s               ft1, ft9, fa2");         printf("-- fmul --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fclass.s             t3, fa2");               printf("-- fclass --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("c.fswsp              ft2, 240(sp)");          printf("-- c.fswsp --\n");    get_MSTATUS_n_check_FS(MSTATUS_EXP_CLEAN); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN); // store does not change freg and fcsr
  __asm__ volatile("fcvt.wu.s            a5, fa1");               printf("-- fcvt.wu.s --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fcvt.s.w             ft6, t6");               printf("-- fcvt.s.w --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fsqrt.s              ft9, fa4, rdn");         printf("-- fsqrt.s --\n");    get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmv.w.x              ft4, s11");              printf("-- fmv.w --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fsgnjn.s             fs9, ft5, ft5");         printf("-- fsgnjn --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmsub.s              fs3, fa0, fa5, fa3");    printf("-- fmsub --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fnmadd.s             ft7, fa7, ft0, fa5");    printf("-- fnmadd --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("feq.s                a3, fa0, ft1");          printf("-- feq --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmadd.s              fa3, ft11, fa1, fa4");   printf("-- fmadd --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fdiv.s               ft6, fa2, fa7, rdn");    printf("-- fdiv --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmin.s               fa2, ft3, fs0");         printf("-- fmin --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fnmsub.s             fa1, fs11, fs5, ft5");   printf("-- fnmsub --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fcvt.s.wu            fa2, s1");               printf("-- fcvt.s.wu --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("c.flwsp              fa3, 28(sp)");           printf("-- c.flwsp --\n");    get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fle.s                t5, fs2, ft2");          printf("-- fle --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fadd.s               fa2, ft2, fs3, rup");    printf("-- fadd --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("c.flw                fa2, 100(a4)");          printf("-- c.flw --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmv.x.w              a5, fs5");               printf("-- fmv.x --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("flt.s                s3, fs7, fa1");          printf("-- flt --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fsw                  fa5, 1692(a1)");         printf("-- fsw --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_CLEAN); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN); // store does not change freg and fcsr
  __asm__ volatile("flw                  fa1, -629(tp)");         printf("-- flw --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fsub.s               fs4, fs7, fs7, rdn");    printf("-- fsub --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("c.fsw                fa4, 32(a1)");           printf("-- c.fsw --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_CLEAN); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN); // store does not change freg and fcsr
  __asm__ volatile("fsgnj.s              fs1, fs0, fs0");         printf("-- fsgnj --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fcvt.w.s             t4, fa1");               printf("-- fcvt.w.s --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fmax.s               ft1, fa7, ft7");         printf("-- fmax --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  __asm__ volatile("fsgnjx.s             fa1, fa1, ft1");         printf("-- fsgnjx --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_CLEAN);
  // INITIAL -> DIRTY
  set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fclass.s             s5, fa0");              printf("-- fclass --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmv.x.w              gp, fs2");              printf("-- fmv.x --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("c.fswsp              ft2, 216(sp)");         printf("-- c.fswsp --\n");    get_MSTATUS_n_check_FS(MSTATUS_EXP_INITIAL); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL); // store does not change freg and fcsr
  __asm__ volatile ("c.flw                fs0, 36(a4)");          printf("-- c.flw --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmin.s               fs6, fs0, fa4");        printf("-- fmin --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fsub.s               fa4, fa6, fa6, rne");   printf("-- fsub --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fsw                  fa7, -1277(a1)");       printf("-- fsw --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_INITIAL); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL); // store does not change freg and fcsr
  __asm__ volatile ("fsgnj.s              ft9, fs10, ft7");       printf("-- fsgnj --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fle.s                t4, fs4, ft2");         printf("-- fle --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmax.s               ft1, fa4, ft11");       printf("-- fmax --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fnmadd.s             ft6, fa7, ft0, fa4");   printf("-- fnmadd --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("c.fsw                fa1, 8(a1)");           printf("-- c.fsw --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_INITIAL); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL); // store does not change freg and fcsr
  __asm__ volatile ("fmul.s               ft1, fs10, fa0, rne");  printf("-- fmul --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fcvt.w.s             t3, ft6, rtz");         printf("-- fcvt.w.s --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("flt.s                s5, fs7, ft6");         printf("-- flt --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fcvt.s.w             ft5, t5, rdn");         printf("-- fcvt.s.w --\n");   get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmv.w.x              ft3, t6");              printf("-- fmv.w --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fnmsub.s             ft7, fs5, fa3, ft3");   printf("-- fnmsub --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fsgnjx.s             fs1, fs1, ft4");        printf("-- fsgnjx --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fcvt.s.wu            fa1, s7, rtz");         printf("-- fcvt.s.wu --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fcvt.wu.s            a4, fa0");              printf("-- fcvt.wu.s --\n");  get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fdiv.s               fs0, fa2, fa6");        printf("-- fdiv --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fsqrt.s              fs7, fs11");            printf("-- fsqrt --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("c.flwsp              fs1, 92(sp)");          printf("-- c.flwsp --\n");    get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fadd.s               fa2, ft1, fs3");        printf("-- fadd --\n");       get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmadd.s              fa3, ft10, fa1, fa4");  printf("-- fmadd --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("feq.s                s1, ft10, ft1");        printf("-- feq --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fsgnjn.s             ft9, ft3, ft3");        printf("-- fsgnjn --\n");     get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("flw                  fa1, -1443(a3)");       printf("-- flw --\n");        get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
  __asm__ volatile ("fmsub.s              fa7, fa0, fa4, fa2");   printf("-- fmsub --\n");      get_MSTATUS_n_check_FS(MSTATUS_EXP_DIRTY); set_MSTATUS_n_check_FS(MSTATUS_FS_INITIAL);
#endif
  
  printf("Number of FS msimatched : %d\n", error);
  return error;
}
