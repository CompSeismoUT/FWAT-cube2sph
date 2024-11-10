!! takes the undeformed partition files, proc*_external_mesh.bin and
!! proc*_adepml_damping_indexing.bin, do node stretching, set up model
!! and output ADE-PML parameter arrays
program cube2sph
  use mpi
  use constants
  use meshfem3D_par, only: LOCAL_PATH
  use meshfem3D_models_par, only: myrank
  use generate_databases_par, only: &
      prname, npts, nodes_coords, nmat_ext_mesh, nundefMat_ext_mesh, &
      materials_ext_mesh, undef_mat_prop, nelmnts_ext_mesh, &
      elmnts_ext_mesh, mat_ext_mesh, NSPEC_AB, &
      nspec2D_xmin, nspec2D_xmax, nspec2D_ymin, nspec2D_ymax, &
      nspec2D_bottom_ext, nspec2D_top_ext, NSPEC2D_BOTTOM, NSPEC2D_TOP, &
      ibelm_xmin, nodes_ibelm_xmin, ibelm_xmax, nodes_ibelm_xmax, &
      ibelm_ymin, nodes_ibelm_ymin, ibelm_ymax, nodes_ibelm_ymax, &
      ibelm_bottom, nodes_ibelm_bottom, ibelm_top, nodes_ibelm_top, &
      nspec_cpml, nspec_cpml_tot, CPML_to_spec, CPML_regions, &
      is_CPML, NPROC, SAVE_MOHO_MESH, &
      !, num_interfaces_ext_mesh, &
      !max_interface_size_ext_mesh, &
      !my_neighbors_ext_mesh, my_nelmnts_neighbors_ext_mesh, &
      !my_interfaces_ext_mesh, ibool_interfaces_ext_mesh, &
      !nibool_interfaces_ext_mesh, num_interface, SAVE_MOHO_MESH, &
      boundary_number, nspec2D_moho_ext, ibelm_moho, nodes_ibelm_moho
  !! ADE-PML:
  use generate_databases_par, only: &
      pml_d,pml_beta,pml_kappa,num_pml_physical,pml_physical_ispec,&
      pml_physical_ijk
      !nglob_CPML,ibool_CPML,CPML_to_glob
  implicit none
  !! local variables
  integer :: ipts, ispec,inode,ier
  double precision, dimension(NGNOD) :: xelm, yelm, zelm
  double precision, dimension(:,:), allocatable :: &
          nodes_coords_sph,nodes_coords_new
  character(len=MAX_STRING_LEN) :: infn, outfn
  double precision, dimension(:,:,:,:), allocatable :: &
          xstore,ystore,zstore,xstore_sph,ystore_sph,zstore_sph,&
          xstore_new,ystore_new,zstore_new,jacobian3D
  real, dimension(:,:,:,:,:,:), allocatable :: r_trans,r_trans_inv
  real, dimension(:,:,:,:), allocatable :: rvolume_loc
  real, dimension(:,:,:), allocatable :: pml_physical_normal
  real, dimension(:,:), allocatable :: pml_physical_jacobianw
  ! C-PML spectral elements global indexing
  integer, dimension(:), allocatable :: CPML_to_spec_dummy

  ! C-PML regions
  integer, dimension(:), allocatable :: CPML_regions_dummy

  ! mask of C-PML elements for the global mesh
  logical, dimension(:), allocatable :: is_CPML_dummy

  call MPI_Init(ier)
  call MPI_Comm_rank(MPI_COMM_WORLD, myrank, ier)
  call MPI_Comm_size(MPI_COMM_WORLD, NPROC, ier)
  LOCAL_PATH = 'DATABASES_MPI'
  call read_partition_files()
  !allocate(nodes_coords_sph(NDIM,npts),stat=ier)
  !allocate(nodes_coords_new(NDIM,npts),stat=ier)
  !! cube2sph transform
  !call cube2sph_trans(nodes_coords,nodes_coords_sph,npts)
  
  allocate(xstore(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
           ystore(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
           zstore(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
  !allocate(xstore_sph(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         ystore_sph(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         zstore_sph(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
  !allocate(xstore_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         ystore_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         zstore_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
  allocate(jacobian3D(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
  !! get all points for undeformed mesh
  call get_gll_xyz(nodes_coords,npts,xstore,ystore,zstore,jacobian3D,NSPEC_AB)
  !! get gll points for spherical mesh, to setup velocity model
  !call get_gll_xyz(nodes_coords_sph,npts,xstore_sph,&
  !        ystore_sph,zstore_sph,jacobian3D,NSPEC_AB)
  

  !allocate(rho_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         vp_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),&
  !         vs_new(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
  !! setup gll model
  !call setup_gll_model_cartesian(xstore_sph,ystore_sph,zstore_sph,&
  !        rho_new,vp_new,vs_new,NSPEC_AB)

  !! node stretching
  !call node_stretching(nodes_coords_sph,nodes_coords_new,npts)
  !! get all points for deformed mesh
  !call get_gll_xyz(nodes_coords_new,npts,xstore_new,&
  !        ystore_new,zstore_new,jacobian3D,NSPEC_AB)

  !! read adepml damping indexing files
  infn = prname(1:len_trim(prname))//'adepml_damping_indexing.bin'
  open(unit=IIN,file=trim(infn),status='unknown',action='read',form='unformatted',iostat=ier)
  read(IIN) nspec_cpml
  if(nspec_cpml>0) then
    allocate(CPML_regions_dummy(nspec_cpml))
    allocate(CPML_to_spec_dummy(nspec_cpml))
    allocate(is_CPML_dummy(NSPEC_AB))
    allocate(pml_d(NDIM,NGLLX,NGLLY,NGLLZ,nspec_cpml))
    allocate(pml_kappa(NDIM,NGLLX,NGLLY,NGLLZ,nspec_cpml))
    allocate(pml_beta(NDIM,NGLLX,NGLLY,NGLLZ,nspec_cpml))
    !allocate(ibool_CPML(NGLLX,NGLLY,NGLLZ,nspec_cpml))
    read(IIN) CPML_regions_dummy
    read(IIN) CPML_to_spec_dummy
    read(IIN) is_CPML_dummy
    read(IIN) pml_d
    read(IIN) pml_beta
    read(IIN) pml_kappa
    !read(IIN) nglob_CPML
    !read(IIN) ibool_CPML
    !allocate(CPML_to_glob(nglob_CPML))
    !read(IIN) CPML_to_glob
  endif
  read(IIN) num_pml_physical
  if (num_pml_physical > 0) then
    allocate(pml_physical_ispec(num_pml_physical))
    allocate(pml_physical_ijk(NDIM, NGLLSQUARE, num_pml_physical))
    read(IIN) pml_physical_ispec
    read(IIN) pml_physical_ijk
  endif
  close(IIN)
  
  if (num_pml_physical > 0) then
    allocate(pml_physical_normal(NDIM,NGLLSQUARE,num_pml_physical))
    allocate(pml_physical_jacobianw(NGLLSQUARE,num_pml_physical))
    call calc_adepml_physical_jacobian(num_pml_physical,xstore,ystore,&
          zstore,NSPEC_AB,pml_physical_ispec,pml_physical_ijk,&
          pml_physical_normal,pml_physical_jacobianw)
  endif

  if (nspec_cpml>0) then
    allocate(r_trans(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,nspec_cpml))
    allocate(r_trans_inv(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,nspec_cpml))
    allocate(rvolume_loc(NGLLX,NGLLY,NGLLZ,nspec_cpml))

    r_trans(:,:,:,:,:,:) = 0.0
    r_trans_inv(:,:,:,:,:,:) = 0.0
    r_trans(1,1,:,:,:,:) = 1.0
    r_trans(2,2,:,:,:,:) = 1.0
    r_trans(3,3,:,:,:,:) = 1.0
    r_trans_inv(1,1,:,:,:,:) = 1.0
    r_trans_inv(2,2,:,:,:,:) = 1.0
    r_trans_inv(3,3,:,:,:,:) = 1.0
    call create_volume_matrices_pml_elastic_loc(NSPEC_AB,jacobian3D,&
          nspec_cpml,rvolume_loc)
    outfn = prname(1:len_trim(prname))//'adepml_param.bin'
    open(unit=IOUT,file=trim(outfn),status='unknown',action='write',form='unformatted',iostat=ier)
    if (num_pml_physical > 0) then
      write(IOUT) pml_physical_normal
      write(IOUT) pml_physical_jacobianw
    endif
    write(IOUT) rvolume_loc
    write(IOUT) r_trans
    write(IOUT) r_trans_inv
    close(IOUT)
  endif
  !call wait_for_attach(myrank)

  !nodes_coords(:,:) = nodes_coords_new(:,:)
  !LOCAL_PATH= 'DATABASES_MPI'
  !call write_partition_files()

  deallocate(xstore,ystore,zstore,jacobian3D)
  if (nspec_cpml > 0) &
    deallocate(CPML_regions_dummy,CPML_to_spec_dummy,is_CPML_dummy,&
               pml_d,pml_kappa,pml_beta)
  if (num_pml_physical > 0) &
    deallocate(pml_physical_ispec,pml_physical_ijk,pml_physical_normal,&
               pml_physical_jacobianw)
  if (nspec_cpml > 0) deallocate(r_trans,r_trans_inv,rvolume_loc)
  call MPI_Finalize(ier)
end program cube2sph

