      logical function sym_abelian_group(geom)
*
* $Id$
*
      implicit none
      integer geom              ! [input]
#include "inp.fh"
c
c     Return true if the point group of the geometry is abelian
c     AND
c     all irreps have size = 1
c
      character*8 group
      integer nab, ind
#ifdef OLD
      parameter (nab = 22)
      character*4 ab(nab)
      data ab/ 'C1','Cs','Ci','C2','D2','C2v','C2h','D2h',
     C     'C3','C4','C5','C6','C7','C8',
     C     'C3h','C4h','C5h','C6h',
     C     'S2','S4','S6','S10'/
#else
c     keep only 1) abelian and 2) with irrep of size 1
      parameter (nab = 9)
      character*4 ab(nab)
      data ab/ 'C1','Cs','Ci','C2','D2','C2v','C2h','D2h',
     C     'S2'/
#endif
c
      call sym_group_name(geom, group)
c
      sym_abelian_group = inp_match(nab,.false.,group,ab,ind)
c
      end
      subroutine sym_abelian_bas_info(basis,
     $     sh_op_map, bf_op_map, bf_phase,
     $     sh_n_uq_op, bf_n_uq_op,
     $     sh_uq_op, bf_uq_op,
     $     sh_n_uq, bf_n_uq,
     $     sh_uq, bf_uq,
     $     sh_nat, bf_nat, sh_uq_bf,
     $     char_tab,
     $     bf_per_ir,
     $     bf_per_ir_cum,
     $     bf_so_ir,
     $     zir,
     $     so_uq_to_lab, so_lab1, so_lab2, oprint)
      implicit none
#include "errquit.fh"
#include "bas.fh"
#include "mafdecls.fh"
#include "sym.fh"
      integer basis             ! [input]
      integer sh_op_map(8,*), bf_op_map(8,*) ! All other arguments are [output]
      double precision bf_phase(8,*) 
      integer sh_n_uq_op(*), bf_n_uq_op(*)
      integer sh_uq_op(8,*), bf_uq_op(8,*)
      integer sh_n_uq, bf_n_uq
      integer sh_uq(*), bf_uq(*)
      integer sh_nat(2,*), bf_nat(2,*), sh_uq_bf(4,*)
      double precision char_tab(1:8,0:7)
      integer bf_per_ir(0:7)
      integer bf_per_ir_cum(0:7)
      integer bf_so_ir(0:7,*)
      character*8 zir(0:7)
      integer so_uq_to_lab(2,0:7,*)
      integer so_lab1(3,*)
      integer so_lab2(*)
      logical oprint            ! [input]
c
c     Returns:
c     
c     sh_op_map(R,ish) the result of applying operator R to shell ish
c     .  R|ish> -> |jsh>
c     .  sh_op_map(R,ish) = jsh
c
c     bf_op_map(R,i) and bf_phase(R,i) are the result of applying operator R
c     to basis function i 
c     .  R|i> -> (+/-)|j>  
c     .  bf_op_map(R,i)   = j
c     .  bf_phase(R,i) = (+/-)1
c
c     sh_n_uq_op(ish) is the number of operations that produce
c     unique results when applied to shell ish (nwchem order).
c
c     bf_n_uq_op(i) is the number of operations that produce unqiue
c     results when applied to basis function i (same as that of ish).
c     This is also the number of irreps that can be generated by
c     applying projectors to this function (1 per irrep).
c
c     sh_uq_op(Ruq,ish) is the list of operators that produce unique
c     results for shell ish
c     .  sh_uq_op(Ruq=1..sh_n_uq_op(ish),ish) = R
c
c     bf_uq_op(Ruq,i) is the list of operators that produce unique
c     results for basis function i (same as that of ish)
c     .  bf_uq_op(Ruq=1..bf_n_uq_op(i),i) = R
c
c     sh_n_uq is the number of symmetry unique shells
c     
c     bf_n_uq is the number of symmetry unique basis functions
c
c     sh_uq(ish_uq=1..sh_n_uq) is the ish_uq'th symmetry unique shell
c     .  in nwchem labelling
c     (lexically highest symmetry related shell)
c
c     bf_uq(iuq=1..bf_n_uq) is the iuq'th symmetry unique basis function
c     .  in nwchem labelling
c     (lexically highest symmetry related basis function)
c
c     sh_nat(1,sh) maps from nwchem to natural AO order (below)
c     sh_nat(2,sh) maps from natural to nwchem AO order (below)
c
c     bf_nat(1,bf) maps from nwchem to natural AO order (below)
c     bf_nat(2,bf) maps from natural to nwchem AO order (below)
c
c     sh_uq_bf(1,shuq) first natural basis function from unique shell
c     sh_uq_bf(2,shuq) last  natural basis function from unique shell
c     sh_uq_bf(3,shuq) first unique  basis function from unique shell
c     sh_uq_bf(4,shuq) last  unique  basis function from unique shell
c
c     char_tab(op,ir) is the character of the operation op for irreducible
c     representation ir (+/- 1).
c
c     bf_per_ir(ir) is the no. of basis functions in this irrep
c
c     bf_per_ir_cum(ir) is the sum of all basis function in irreps.
c     lower than ir
c     .  bf_per_ir_cum(ir) = sum(k=0..ir-1) bf_per_ir(k)
c
c     bf_so_ir(iruq=1..bf_n_uq_op(bf_uq(iuq)),iuq) is the list of irreps that
c     can be generated from unique function iuq (with 1 function per irrep.)
c
c     zir(ir) returns the name of the irrep
c
c     (see below for decsription of the labelling of SOs)
c     so_uq_to_lab(1,ir,iuq) = lab1 = SO label for projector for ir 
c     .  acting on the iuq'th unique basis function or a negative
c     .  no. if the projector yields zero.
c     so_uq_to_lab(2,ir,iuq) = lab2 = second type of SO label
c
c     so_lab1(1,lab1) = irrep of given SO
c     so_lab1(2,lab1) = lab2 = mapping between labelling schemes
c     so_lab1(3,lab1) = iuq = unique basis function that is generator
c
c     so_lab2(lab2) = lab1 = map from symmetry blocked SO order 
c     .  (second labeling scheme) to natural SO order (first scheme).
c
c     Unlike the rest of the symmetry code this routine INCLUDES
c     the identity as the first operator, whereas the rest of
c     the symmetry code does not include the identity.
c
c     Also, note that irreduible representations are numbered
c     from 0 to nir-1 so that the group multiplication table 
c     can be computed using sym1*sym2=ieor(sym1,sym2)
c     (ugh ... operators are still numbered from 1)
c     
c
      integer geom, nop, l_a, k_a, l_b, k_b, nbf, nsh
      integer i, j, ish, jsh, ir, op, opuq, ilo, ihi, iuq
      integer countsh, countbf, countuqbf
      integer lab1, lab2(0:7), label2
      integer nbfir
      double precision c(8), val
      double precision ddot
      external ddot
c
      if (.not. bas_geom(basis,geom))
     $     call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
      if (.not. bas_numbf(basis,nbf))
     $     call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
      if (.not. bas_numcont(basis,nsh))
     $     call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
c
      if (.not. sym_abelian_group(geom))
     $     call errquit('the point group is not abelian',0, INPUT_ERR)
c
      nop = sym_number_ops(geom) + 1
      if (.not. ma_push_get(mt_dbl, nbf, 'abel a', l_a, k_a))
     $     call errquit('sym_abel_bas_info: ma?', nbf, MA_ERR)
      if (.not. ma_push_get(mt_dbl, nbf, 'abel b', l_b, k_b))
     $     call errquit('sym_abel_bas_info: ma?', nbf, MA_ERR)
c
c     Construct the effect of the group operations on shells and
c     basis functions using the existing routine to apply an
c     operator to an MO vector ... brute force but correct.
c
      do ish = 1, nsh
         sh_op_map(1,ish) = ish     ! identity
         if (.not. bas_cn2bfr(basis, ish, ilo, ihi))
     $        call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
         
         do i = ilo, ihi
            bf_op_map(1,i)   = i    ! identity
            bf_phase(1,i) = 1.0d0
            call dfill(nbf, 0.0d0, dbl_mb(k_a), 1)
            dbl_mb(k_a+i-1) = 1.0d0
            do op = 2,nop
               call dfill(nbf, 0.0d0, dbl_mb(k_b), 1)
               call sym_movecs_apply_op(basis, op-1,
     $              dbl_mb(k_a), dbl_mb(k_b)) 
               do j = 1, nbf
                  if (abs(abs(dbl_mb(k_b+j-1))-1.0d0) .lt. 1d-12) then
                     bf_op_map(op,i) = j
                     bf_phase(op,i) = dbl_mb(k_b+j-1)
                     goto 10
                  end if
               end do
               call errquit('sym_abelian_bas_info: _op_map failed',i,
     &       BASIS_ERR)
 10            continue
               if (.not. bas_bf2cn(basis, j, jsh))
     $              call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
               sh_op_map(op,ish) = jsh
            end do
         end do
      end do
c
      if (.not. ma_chop_stack(l_a)) call errquit
     $     ('sym_abelian: ma corrupted', 0, MA_ERR)
c
      if (oprint) then
         write(6,*) ' Abelian group shell symmetry _op_map'
         do ish = 1, nsh
            write(6,11) ish,(sh_op_map(op,ish),op=1,nop)
 11         format(i5,3x,8i5)
         end do
         write(6,*) ' Abelian group basis function symmetry _op_map'
         do i = 1, nbf
            write(6,11)i,(nint(bf_op_map(op,i)*bf_phase(op,i)),op=1,nop)
         end do
      endif
c
c     Determine for each shell/bf the operations that generate 
c     all symmetry related shells.
c
      call ifill(nsh, 0, sh_n_uq_op, 1)
      call ifill(nbf, 0, bf_n_uq_op, 1)
      do ish = 1, nsh
         do op = 1, nop
            do opuq = 1, sh_n_uq_op(ish)
               if (sh_op_map(sh_uq_op(opuq,ish),ish) .eq. 
     $              sh_op_map(op,ish)) goto 20
            end do
            sh_n_uq_op(ish) = sh_n_uq_op(ish) + 1
            sh_uq_op(sh_n_uq_op(ish),ish) = op
            if (.not. bas_cn2bfr(basis, ish, ilo, ihi))
     $           call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
            do i = ilo, ihi
               bf_n_uq_op(i) = bf_n_uq_op(i) + 1
               bf_uq_op(bf_n_uq_op(i),i) = op
            end do
 20         continue
         end do
      end do
c
      if (oprint) then
         write(6,*) ' Abelian symmetry unique operations by shell'
         do ish = 1, nsh
            write(6,22) ish,(sh_uq_op(opuq,ish), opuq=1,sh_n_uq_op(ish))
 22         format(i5,2x,8i3)
         end do
         write(6,*) ' Abelian symmetry unique operations by function'
         do i = 1, nbf
            write(6,22) i, (bf_uq_op(opuq,i), opuq=1,bf_n_uq_op(i))
         end do
      endif
c
c     Determine the lexically highest symmetry related shells/bfc
c     
      sh_n_uq = 0
      bf_n_uq = 0
      do ish = 1, nsh
         do op = 1, nop
            if (ish .lt. sh_op_map(op,ish)) goto 30
         end do
         sh_n_uq = sh_n_uq + 1
         sh_uq(sh_n_uq) = ish
         if (.not. bas_cn2bfr(basis, ish, ilo, ihi))
     $        call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
         do i = ilo, ihi
            bf_n_uq = bf_n_uq + 1
            bf_uq(bf_n_uq) = i
         end do
 30      continue
      end do
c     
      if (oprint) then
         write(6,*) ' Abelian symmetry unique shells', sh_n_uq
         write(6,33) (sh_uq(ish),ish=1,sh_n_uq)
 33      format(15i5)
         write(6,*) ' Abelian symmetry unique functions', bf_n_uq
         write(6,33) (bf_uq(i),i=1,bf_n_uq)
      endif
c
c     The "natural order" of AO shells and basis functions
c     has all symmetry related quantities next to each other.
c
      call ifill(2*nsh, -1, sh_nat, 1)
      call ifill(2*nbf, -1, bf_nat, 1)
      countsh = 0
      countbf = 0
      countuqbf = 0
      do iuq = 1, sh_n_uq
         ish = sh_uq(iuq)
         if (.not. bas_cn2bfr(basis, ish, ilo, ihi))
     $        call errquit('sym_abelian_bas_info: basis?', basis,
     &       BASIS_ERR)
         sh_uq_bf(1,iuq) = countbf+1
         sh_uq_bf(3,iuq) = countuqbf+1
         do opuq = 1, sh_n_uq_op(ish)
            countsh = countsh + 1
            op = sh_uq_op(opuq, ish)
            jsh = sh_op_map(op,ish)
            sh_nat(1,jsh) = countsh
            sh_nat(2,countsh) = jsh
         end do
         do i = ilo, ihi
            do opuq = 1, sh_n_uq_op(ish)
               countbf = countbf + 1
               op = sh_uq_op(opuq, ish)
               j = bf_op_map(op,i)
               bf_nat(1,j) = countbf
               bf_nat(2,countbf) = j
            end do
         end do
         countuqbf = countuqbf + (ihi-ilo+1)
         sh_uq_bf(2,iuq) = countbf
         sh_uq_bf(4,iuq) = countuqbf
      end do
      if (countbf.ne.nbf .or. countsh.ne.nsh .or.
     $     countuqbf.ne.bf_n_uq) call errquit
     $     ('robert cannot count',0, UNKNOWN_ERR)
      do i = 1, nbf
         if (bf_nat(1,i).le.0 .or. bf_nat(2,i).le.0)
     $        call errquit('missing bf_nat?',0, UNKNOWN_ERR)
      end do
      do i = 1, nsh
         if (sh_nat(1,i).le.0 .or. sh_nat(2,i).le.0)
     $        call errquit('missing sh_nat?',0, UNKNOWN_ERR)
      end do
      if (oprint) then
         write(6,*) ' Shell nwchem to natural map and check'
         do ish = 1, nsh
            write(6,101) ish, sh_nat(2,sh_nat(1,ish)), sh_nat(1,ish)
 101        format(2i5,2x,i5)
         end do
         write(6,*) ' Function nwchem to natural map and check'
         do i = 1, nbf
            write(6,101) i, bf_nat(2,bf_nat(1,i)), bf_nat(1,i)
         end do
         write(6,*) ' Range of natural order functions from unique sh'
         do i = 1, sh_n_uq
            write(6,77) i, sh_uq_bf(1,i), sh_uq_bf(2,i)
         end do
         write(6,*) ' Range of unique order functions from unique sh'
         do i = 1, sh_n_uq
            write(6,77) i, sh_uq_bf(3,i), sh_uq_bf(4,i)
         end do
      end if
c
c     Symmetry orbitals (SO) are formed by applying a projector
c     to the generating functions (the symmetry unique or lexically
c     highest symmetry related functions).
c
c     The number of symmetry related functions (bf_n_uq_op(i)) 
c     is also the number of irreducible representations spanned
c     by the symmetry related functions (Abelian groups only).
c
      call sym_abelian_char_tab(geom, char_tab, zir)
      call ifill(8, 0, bf_per_ir, 1)
c
c     Loop thru  generators, compute the character
c     and hence the irreps spanned.
c
      do iuq = 1, bf_n_uq       ! Loop over generators
         i = bf_uq(iuq)
c
         do op = 1, nop
            if (bf_op_map(op,i) .eq. i) then
               c(op) = bf_n_uq_op(i)*bf_phase(op,i)
            else
               c(op) = 0.0d0
            endif
         end do
c
         nbfir = 0
         do ir = 0, nop-1
            val = ddot(nop, c, 1, char_tab(1,ir), 1) / dble(nop)
            if (abs(val-1.0d0) .lt. 1d-12) then
               nbfir = nbfir + 1
               bf_so_ir(nbfir,iuq) = ir
               bf_per_ir(ir) = bf_per_ir(ir) + 1
            else if (val .lt. -1d-12) then
               call errquit('sym_abelian_bas_info: neg. proj?',0,
     &       BASIS_ERR)
            end if
         end do
      end do
c
c     Check no. of bf per irrep against standard routine
c
      call sym_bas_irreps(basis, .false., bf_per_ir_cum)
      do ir = 0, nop-1
         if (bf_per_ir_cum(ir) .ne. bf_per_ir(ir)) call errquit
     $        ('sym_abelian_bas_info: miscount of functions', ir,
     &       BASIS_ERR)
      end do
c
      nbfir = 0
      do ir = 0, nop-1
         bf_per_ir_cum(ir) = nbfir
         nbfir = nbfir + bf_per_ir(ir)
      end do
      if (oprint) then
         write(6,123) ' bf_per_ir_cum ', (bf_per_ir_cum(ir),ir=0,nop-1)
         write(6,123) ' bf_per_ir     ', (bf_per_ir(ir),ir=0,nop-1)
 123     format(1x,a,8i5)
      endif
c
      if (oprint) then
         write(6,*) ' Symmetry of SOs in natural order '
         nbfir = 1
         do iuq = 1, bf_n_uq
            i = bf_uq(iuq)
            write(6,124)nbfir,(zir(bf_so_ir(ir,iuq)),ir=1,bf_n_uq_op(i))
 124        format(i5,2x,8(a4,1x))
            nbfir = nbfir + bf_n_uq_op(i)
         end do
      end if
c
c     The SO coefficients of the functions arsing from basis function i
c     are given by the projector
c
c     .   |ir> = (1/h(i)) sum(unique ops for i) chartab(op,ir) |op * i>
c
c     with 
c
c     .   |op * i> = bf_phase(op,i) * |bf_op_map(op,i)>
c     .   h(i) = number of unique ops for i.
c
c     Next, we must compute the various ways of numbering the SOs
c
c     The natural order (lab1) is as above and is used when generating 
c     integrals over the SOs, but a more useful order (lab2) blocks
c     the functions by irrep.
c
c     lab1 = 0
c     lab2(0:7) = 0
c     loop over unique shells
c     .  loop over functions in shell
c     .     loop over irreps
c     .        if (non-zero from projector) then 
c     .          lab1 = lab1 + 1
c     .          lab2(ir) = lab2(ir) + 1
c     .          label2 = lab2(ir) + bf_per_ir_cum(ir)
c     
c     i.e, lab1 = lab1(irrep, shell component, unique shell).
c
c     We need maps between the various labeling schemes.
c
c     Given the AO basis function number of the generator and the irrep
c     .      what is the natural SO number (lab1)
c     .      what is the sorted SO number (lab2)
c
c     Given lab1 
c     .      what is the ir
c     .      what is the lab2
c     .      what is the generator AO basis function
c
c     Given lab2
c     .      what is the lab1
c
      call ifill(8,0,lab2,1)
      call ifill(2*8*nbf,-99999999,so_uq_to_lab,1)
      call ifill(3*nbf,-99999999,so_lab1,1)
      call ifill(nbf,  -99999999,so_lab2,1)
      lab1 = 0
      do iuq = 1, bf_n_uq
         i = bf_uq(iuq)
         do opuq = 1, bf_n_uq_op(i)
            ir = bf_so_ir(opuq,iuq)
c
            lab1 = lab1 + 1
            lab2(ir) = lab2(ir) + 1
            label2 = lab2(ir) + bf_per_ir_cum(ir)
c
            so_uq_to_lab(1,ir,iuq) = lab1 
            so_uq_to_lab(2,ir,iuq) = label2
            so_lab1(1,lab1) = ir
            so_lab1(2,lab1) = label2
            so_lab1(3,lab1) = iuq
            so_lab2(label2) = lab1
         end do
      end do
c
      if (oprint) then
         write(6,*) ' Map from unique bf to lab1 and lab2'
         do iuq = 1, bf_n_uq
            i = bf_uq(iuq)
            write(6,77) iuq,
     $           (so_uq_to_lab(1,bf_so_ir(ir,iuq),iuq),
     $           so_uq_to_lab(2,bf_so_ir(ir,iuq),iuq),
     $           ir=1,bf_n_uq_op(i))
 77         format(i5,8(2x,2i4))
         end do
         write(6,*) ' Map from lab1 to ir, lab2, unique and test lab2'
         do lab1 = 1, nbf
            write(6,78) lab1, so_lab2(so_lab1(2,lab1)),
     $           (so_lab1(i,lab1), i=1,3)
 78         format(2i5,2x,3i4)
         end do
         write(6,*) ' Map from lab2 to lab1 '
         do i = 1, nbf
            write(6,79) i, so_lab2(i)
 79         format(i5,2x,i5)
         end do
      end if
c
      end
      subroutine sym_abelian_char_tab(geom, char_tab, zir)
      implicit none
#include "errquit.fh"
c
      integer geom              ! [input]
      double precision char_tab(8,8) ! [output] char_tab(op,irrep)
      character*8 zir(8)
c
c     Return the character table conveniently dimensioned
c     and with the classes/operations reordered so that
c     they are in the correct order.
c
      integer maxireps, maxops
      parameter (maxireps = 20, maxops=120)
      integer op_class_index(maxops)
      integer nop,  iclass_dim(maxireps)
      character*8 zclass(maxireps), group_name
      double precision chars(maxireps*maxireps)
c
      integer ir, op, class, nir
      logical sym_char_table
      external sym_char_table
c
      call sym_op_classify(geom, op_class_index)
      call sym_group_name(geom,group_name)
      if (.not. sym_char_table(group_name, nop, nir, iclass_dim,
     $     zir, zclass, chars)) 
     $     call errquit('sym_abelian_char_table: no char table',0,
     &       INPUT_ERR)
c
      call dfill(8*8, 0.0d0, char_tab, 1)
c
      do ir = 1, nir
         char_tab(1,ir) = chars((ir-1)*nir+1)
         do op = 2, nop
            class = op_class_index(op-1) ! Note -1
            char_tab(op,ir) = chars((ir-1)*nir+class)            
         end do
      end do
c
      end

#ifdef BAD_FOR_G77
      logical function sym_force_abelian_subgroup(geom)
c
c     This reduces non-Abelian groups to the appropriate Abelian subgroup
c
      implicit none
      integer geom              ! [input]
#include "inp.fh"
#include "nwc_const.fh"
#include "geomP.fh"
c
      character*8 oldgroup,newgroup
      integer nab
      parameter (nab = 8)
      character*4 ab(nab)
      data ab/ 'C1','Cs','Ci','C2','D2','C2v','C2h','D2h'/
      logical sym_abelian_group
      external sym_abelian_group
c
      call sym_group_name(geom,oldgroup)
      print*,'oldgroup = ',oldgroup
c
      if (oldgroup(1:3).eq.'D4h') then
        group_name = 'D2h       '
      else ! give up and turn off symmetry
        group_name = 'C1        '
      endif
c
      call sym_group_name(geom,newgroup)
      print*,'newgroup = ',newgroup
c
      sym_force_abelian_subgroup = sym_abelian_group(geom)
c
      end
#endif
