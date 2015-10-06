! $Id$
!
!  This module takes care of everything related to particle spin
!  including lifting forces. The module maintains a full f-array
!  vorticity field, to be able to interpolate on the flow vorticity.
!
!  The module should be considered experimental as it is virtually
!  untested (as of aug-08).
!
!  NOTE: all code relating to particle spin or the magnus force
!        have been commented out.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
!!! MAUX CONTRIBUTION 3
!!! COMMUNICATED AUXILIARIES 3
! MPVAR CONTRIBUTION 3
! CPARAM logical, parameter :: lparticles_spin = .true.
!
!***************************************************************
module Particles_spin
!
  use Cdata
  use Cparam
  use Messages
  use Particles_cdata
!
  implicit none
!
  include 'particles_spin.h'
!
  character(len=labellen), dimension(ninit) :: initsp = 'nothing'
  logical :: lsaffman_lift = .false.
  logical :: lmagnus_lift = .false.
!
  namelist /particles_spin_init_pars/ lsaffman_lift, lmagnus_lift, initsp
!
  namelist /particles_spin_run_pars/ lsaffman_lift, lmagnus_lift
!
  integer :: idiag_psxm = 0, idiag_psym = 0, idiag_pszm = 0
!
  contains
!***********************************************************************
    subroutine register_particles_spin()
!
!  Set up indices for access to the fp and dfp arrays.
!
!  21-jul-08/kapelrud: coded
!
!      use FArrayManager
!
      if (lroot) call svn_id("$Id$")
!!
!!  Indices for flow field vorticity. The vorticity is a communicated auxiliary
!!  vector.
!!  Assuming that this module is the last to use communicated aux variables,
!!  then the three last entries in bc{x,y,z} in start.in sets the boundary
!!  conditions of the vorticity.
!!
!      call farray_register_auxiliary('ox', iox, communicated=.true.)
!      call farray_register_auxiliary('oy', ioy, communicated=.true.)
!      call farray_register_auxiliary('oz', ioz, communicated=.true.)
!
!  Indices for particle spin
!
      ipsx = npvar + 1
      pvarname(ipsx) = 'ipsx'
      ipsy = npvar + 2
      pvarname(ipsy) = 'ipsy'
      ipsz = npvar + 3
      pvarname(ipsz) = 'ipsz'
!
      npvar = npvar + 3
!
!  Check that the fp and dfp arrays are big enough.
!
      bound: if (npvar > mpvar) then
        if (lroot) print *, 'npvar = ', npvar, ', mpvar = ', mpvar
        call fatal_error('register_particles_spin', 'npvar > mpvar')
      endif bound
!!
!!  Make sure that the vorticity field is communicated one time extra
!!  before the pencil loop in pde is executed.
!!
!      lparticles_prepencil_calc=.true.
!
    endsubroutine register_particles_spin
!***********************************************************************
    subroutine initialize_particles_spin(f)
!
!  Perform any post-parameter-read initialization, i.e., calculate
!  derived parameters.
!
!  21-jul-08/kapelrud: coded
!
      use General, only: keep_compiler_quiet
!      use Particles_radius
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
      if (lsaffman_lift) call fatal_error('initialize_particles_spin', 'Saffman lift is currently not supported. ')
!
      if (lmagnus_lift) call fatal_error('initialize_particles_spin', 'Magnus lift is under construction. ')
!!
!!  Initialize vorticity field to zero.
!!
!      f(:,:,:,iox:ioz) = 0.0
!!
!!  Request interpolation of variables:
!!
!      interp%luu = interp%luu .or. lsaffman_lift !.or. lmagnus_lift
!      interp%loo = interp%loo .or. lsaffman_lift !.or. lmagnus_lift
!      interp%lrho = interp%lrho .or. lsaffman_lift !.or. lmagnus_lift
!
    endsubroutine initialize_particles_spin
!***********************************************************************
    subroutine init_particles_spin(f, fp)
!
!  Initial spin of particles.
!
!  21-jul-08/kapelrud: coded
!
      use General, only: keep_compiler_quiet
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mpar_loc,mparray), intent(inout) :: fp
!
      integer :: j
!
      call keep_compiler_quiet(f)
!
      loop: do j = 1, ninit
        init: select case (initsp(j))
!
!  Do nothing.
!
        case ('nothing') init
          if (lroot .and. j == 1) print *, 'init_particles_spin: no initial condition for particle spin'
!
!  Zero out all spins.
!
        case ('zero') init
          if (lroot) print *, 'init_particles_spin: zero particle spin'
          fp(1:npar_loc,ipsx:ipsz) = 0.0
!
!  Unknown initial condition.
!
        case default init
          call fatal_error('init_particles_spin', 'unknown initsp = ' // initsp(j))
!
        endselect init
      enddo loop
!
    endsubroutine init_particles_spin
!***********************************************************************
    subroutine particles_spin_prepencil_calc(f)
!
!  Prepare the curl(uu) field here so that ghost zones can be
!  communicated between processors before the spin is calculated in
!  dps_dt_pencil.
!
!  22-jul-08/kapelrud: coded
!  20-sep-15/ccyang: Disable this subroutine for the moment.
!
      use General, only: keep_compiler_quiet
!      use Sub, only: curl
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
!      real, dimension(nx,3) :: tmp
!!
!!  Calculate curl(uu) along pencils in the internal region of this
!!  processor's grid. Ghost zones will have to be set by the boundary conditions
!!  and mpi communication as usual.
!!
!      do m=m1,m2;do n=n1,n2
!        call curl(f,iux,tmp)
!        f(l1:l2,m,n,iox:ioz) = tmp
!      enddo;enddo
!
    endsubroutine particles_spin_prepencil_calc
!***********************************************************************
    subroutine pencil_criteria_par_spin()
!
!  All pencils that the Particles_spin module depends on are specified
!  here.
!
!  06-oct-15/ccyang: stub.
!
    endsubroutine pencil_criteria_par_spin
!***********************************************************************
    subroutine dps_dt_pencil(f, df, fp, dfp, p, ineargrid)
!
!  Evolution of particle spin (called in the pencil loop.)
!
!  06-oct-15/ccyang: stub.
!
      use General, only: keep_compiler_quiet
!      use Viscosity, only: getnu
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mx,my,mz,mvar), intent(in) :: df
      real, dimension(mpar_loc,mparray), intent(in) :: fp
      real, dimension(mpar_loc,mpvar), intent(inout) :: dfp
      type(pencil_case), intent(in) :: p
      integer, dimension(mpar_loc,3), intent(in) :: ineargrid
!
      logical :: lfirstcall = .true.
!      real, dimension(3) :: tau
      logical :: lheader
!      integer :: k
!      real :: ip_tilde, nu
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(dfp)
!
!      call getnu(nu_input=nu)
!
!  Print out header information in first time step.
!
      lheader = lfirstcall .and. lroot
      lfirstcall = .false.
!
!  Identify module and boundary conditions.
!
      if (lheader) print *, 'dps_dt_pencil: Calculate dps_dt (currently do nothing)'
!!
!!  Calculate torque on particle due to the shear flow, and
!!  update the particles' spin.
!!
!     if (lmagnus_lift) then
!       do k=k1_imn(imn),k2_imn(imn)
!!
!!  Calculate angular momentum
!!
!         ip_tilde=0.4*mpmat*fp(k,iap)**2
!!
!         tau=8.0*pi*interp_rho(k)*nu*fp(k,iap)**3* &
!             (0.5*interp_oo(k,:)-fp(k,ipsx:ipsz))
!         dfp(k,ipsx:ipsz)=dfp(k,ipsx:ipsz)+tau/ip_tilde
!       enddo
!     endif
!
    endsubroutine dps_dt_pencil
!***********************************************************************
    subroutine dps_dt(f, df, fp, dfp, ineargrid)
!
!  Evolution of particle spin (called after the pencil loop.)
!
!  25-jul-08/kapelrud: coded
!
      use Particles_sub, only: sum_par_name
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mx,my,mz,mvar), intent(in) :: df
      real, dimension(mpar_loc,mparray), intent(in) :: fp
      real, dimension(mpar_loc,mpvar), intent(in) :: dfp
      integer, dimension(mpar_loc,3), intent(in) :: ineargrid
!
!  Diagnostics
!
      diag: if (ldiagnos) then
        if (idiag_psxm /= 0) call sum_par_name(fp(1:npar_loc,ipsx), idiag_psxm)
        if (idiag_psym /= 0) call sum_par_name(fp(1:npar_loc,ipsy), idiag_psym)
        if (idiag_pszm /= 0) call sum_par_name(fp(1:npar_loc,ipsz), idiag_pszm)
      endif diag
!
    endsubroutine dps_dt
!***********************************************************************
    subroutine read_particles_spin_init_pars(iostat)
!
!  Read initialization parameters from namelist particles_spin_init_pars.
!
!  06-oct-15/ccyang: coded.
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=particles_spin_init_pars, IOSTAT=iostat)
!
    endsubroutine read_particles_spin_init_pars
!***********************************************************************
    subroutine write_particles_spin_init_pars(unit)
!
!  Write initialization parameters from namelist particles_spin_init_pars.
!
!  06-oct-15/ccyang: coded.
!
      integer, intent(in) :: unit
!
      write(unit, NML=particles_spin_init_pars)
!
    endsubroutine write_particles_spin_init_pars
!***********************************************************************
    subroutine read_particles_spin_run_pars(iostat)
!
!  Read runtime parameters from namelist particles_spin_run_pars.
!
!  06-oct-15/ccyang: coded.
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=particles_spin_run_pars, IOSTAT=iostat)
!
    endsubroutine read_particles_spin_run_pars
!***********************************************************************
    subroutine write_particles_spin_run_pars(unit)
!
!  Write runtime parameters from namelist particles_spin_run_pars.
!
!  06-oct-15/ccyang: coded.
!
      integer, intent(in) :: unit
!
      write(unit, NML=particles_spin_run_pars)
!
    endsubroutine write_particles_spin_run_pars
!***********************************************************************
    subroutine rprint_particles_spin(lreset, lwrite)
!
!  Read and register print parameters relevant for particles spin.
!
!  21-jul-08/kapelrud: coded.
!  06-oct-15/ccyang: continued.
!
      use Diagnostics
!
      logical, intent(in) :: lreset
      logical, intent(in), optional :: lwrite
!
      logical :: lwr
      integer :: iname
!
!  Write information to index.pro
!
      lwr = .false.
      if (present(lwrite)) lwr = lwrite
!
      indices: if (lwr) then
        write(3,*) "ipsx = ", ipsx
        write(3,*) "ipsy = ", ipsy
        write(3,*) "ipsz = ", ipsz
      endif indices
!
!  Reset everything in case of reset
!
      reset: if (lreset) then
        idiag_psxm = 0
        idiag_psym = 0
        idiag_pszm = 0
      endif reset
!
!  Run through all possible names that may be listed in print.in
!
      if (lroot .and. ip < 14) print *, 'rprint_particles_spin: run through parse list'
      diag: do iname = 1, nname
        call parse_name(iname, cname(iname), cform(iname), 'psxm', idiag_psxm)
        call parse_name(iname, cname(iname), cform(iname), 'psym', idiag_psym)
        call parse_name(iname, cname(iname), cform(iname), 'pszm', idiag_pszm)
      enddo diag
!
    endsubroutine rprint_particles_spin
!***********************************************************************
    subroutine calc_liftforce(fp, k, rep, liftforce)
!
!  Calculate lifting forces for a given particle. It should be possible
!  to make this a routine operating on pencils.
!
!  22-jul-08/kapelrud: coded
!
      real, dimension(mparray), intent(in) :: fp
      integer, intent(in) :: k
      real, intent(in) :: rep
      real, dimension(3), intent(out) :: liftforce
!
      real,dimension(3) :: dlift
!
!  Initialization
!
      liftforce = 0.0
!
!  Find Saffman lift.
!
!      if (lsaffman_lift) then
!        call calc_saffman_liftforce(fp,k,rep,dlift)
!        liftforce=liftforce+dlift
!      endif
!
!  Find Magnus list.
!
     magnus: if (lmagnus_lift) then
       call calc_magnus_liftforce(fp, k, rep, dlift)
       liftforce = liftforce + dlift
     endif magnus
!
    endsubroutine calc_liftforce
!***********************************************************************
    subroutine calc_saffman_liftforce(fp,k,rep,dlift)
!
!  Calculate the Saffman lifting force for a given particles.
!
!  16-jul-08/kapelrud: coded
!
      use Particles_cdata
      use Sub, only: cross
      use Viscosity, only: getnu
!
      real,dimension(mparray) :: fp
      integer :: k
      real,dimension(3) :: dlift
      real :: rep
!
      intent(in) :: fp, k, rep
      intent(out) :: dlift
!
      real :: csaff,diameter,beta,oo,nu
!
      call getnu(nu_input=nu)
!
      if (.not.lparticles_radius) then
        if (lroot) print*,'calc_saffman_liftforce: '//&
             'Particle_radius module must be enabled!'
        call fatal_error('calc_saffman_liftforce','')
      endif
!
      diameter=2*fp(iap)
      oo=sqrt(sum(interp_oo(k,:)**2))
!
      beta=diameter**2*oo/(2.0*rep*nu)
      if (beta<0.005) then
        beta=0.005
      elseif (beta>0.4) then
        beta=0.4
      endif
!
      if (rep<=40) then
        csaff=(1-0.3314*beta**0.5)*exp(-rep/10.0)+0.3314*beta**0.5
      else
        csaff=0.0524*(beta*rep)**0.5
      endif
!
      call cross(interp_uu(k,:)-fp(ivpx:ivpz),interp_oo(k,:),dlift)
      dlift=1.61*csaff*diameter**2*nu**0.5*&
                 interp_rho(k)*oo**(-0.5)*dlift/mpmat
!
    endsubroutine calc_saffman_liftforce
!***********************************************************************
    subroutine calc_magnus_liftforce(fp, k, rep, dlift)
!
!  Calculate the Magnus liftforce for a given spinning particle.
!
!  22-jul-08/kapelrud: coded
!
      use Sub, only: cross
      use Viscosity, only: getnu
!
      real, dimension(mparray), intent(in) :: fp
      integer, intent(in) :: k
      real, intent(in) :: rep
      real, dimension(3), intent(out) :: dlift
!
      real :: const_lr, spin_omega, area, nu
      real, dimension(3) :: ps_rel, uu_rel
!
      if (.not.lparticles_radius) then
        if (lroot) print*,'calc_magnus_liftforce: '//&
             'Particle_radius module must be enabled!'
        call fatal_error('calc_magnus_liftforce','')
      endif
!
      call getnu(nu_input=nu)
!
!  Projected area of the particle
!
      area=pi*fp(iap)**2
!
!  Calculate the Magnus lift coefficent
!
      uu_rel=interp_uu(k,:)-fp(ivpx:ivpz)
      spin_omega=fp(iap)*sqrt(sum(fp(ipsx:ipsz)**2))/sqrt(sum(uu_rel**2))
      const_lr=min(0.5,0.5*spin_omega)
!
      ps_rel=fp(ipsx:ipsz)-0.5*interp_oo(k,:)
      call cross(uu_rel,ps_rel,dlift)
      dlift=dlift/sqrt(sum(ps_rel**2))
      dlift=0.25*interp_rho(k)*(rep*nu/fp(iap))*const_lr*area/mpmat*dlift
!
    endsubroutine calc_magnus_liftforce
!***********************************************************************
endmodule Particles_spin
