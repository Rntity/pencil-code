; +
; NAME:
;       PC_READ_VAR_RAW
;
; PURPOSE:
;       Read var.dat, or other VAR files in an efficient way!
;
;       Returns one array from a snapshot (var) file generated by a
;       Pencil Code run, and another array with the variable labels.
;       Works for one or all processors.
;       This routine can also read reduced datasets from 'pc_reduce.x'.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_var_raw, object=object, varfile=varfile, tags=tags,   $
;                    datadir=datadir, proc=proc, /allprocs, /quiet,   $
;                    trimall=trimall, swap_endian=swap_endian,        $
;                    f77=f77, time=time, grid=grid, var_list=var_list
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;       proc: Specifies processor to get the data from. Default: ALL [integer]
;    varfile: Name of the var file. Default: 'var.dat'.              [string]
;   allprocs: Load distributed (0) or collective (1 or 2) varfiles.  [integer]
;   /reduced: Load previously reduced collective varfiles (implies allprocs=1).
;
;     object: Optional object in which to return the loaded data.    [4D-array]
;       tags: Array of tag names inside the object array.            [string(*)]
;   var_list: Array of varcontent idlvars to read (default = all).   [string(*)]
;
;   /trimall: Remove ghost points from the returned data.
;     /quiet: Suppress any information messages and summary statistics.
;
; EXAMPLES:
;       pc_read_var_raw, obj=vars, tags=tags            ;; read from data/proc*
;       pc_read_var_raw, obj=vars, tags=tags, proc=5    ;; read from data/proc5
;       pc_read_var_raw, obj=vars, tags=tags, /allprocs ;; read from data/allprocs
;       pc_read_var_raw, obj=vars, tags=tags, /reduced  ;; read from data/reduced
;
;       cslice, vars
; or:
;       cmp_cslice, { uz:vars[*,*,*,tags.uz], lnrho:vars[*,*,*,tags.lnrho] }
;
; MODIFICATION HISTORY:
;       $Id$
;       Adapted from: pc_read_var.pro, 25th January 2012
;
;-
pro pc_read_var_raw,                                                  $
    object=object, varfile=varfile, datadir=datadir, tags=tags,       $
    dim=dim, param=param, par2=par2, varcontent=varcontent, f77=f77,  $
    proc=proc, allprocs=allprocs, trimall=trimall, quiet=quiet,       $
    swap_endian=swap_endian, time=time, grid=grid, reduced=reduced,   $
    var_list=var_list

COMPILE_OPT IDL2,HIDDEN
;
; Use common block belonging to derivative routines etc. so we can
; set them up properly.
;
  common cdat, x, y, z, mx, my, mz, nw, ntmax, date0, time0, nghostx, nghosty, nghostz
  common cdat_limits, l1, l2, m1, m2, n1, n2, nx, ny, nz
  common cdat_grid, dx_1, dy_1, dz_1, dx_tilde, dy_tilde, dz_tilde, lequidist, lperi, ldegenerated
  common pc_precision, zero, one
  common cdat_coords, coord_system
;
; Default settings.
;
  default, swap_endian, 0
  default, reduced, 0
  if (keyword_set (reduced)) then allprocs = 1
;
; Default data directory.
;
  if (not keyword_set (datadir)) then datadir = pc_get_datadir()
;
; Name and path of varfile to read.
;
  if (not keyword_set (varfile)) then varfile = 'var.dat'
;
; Check if reduced keyword is set.
;
if (keyword_set (reduced) and (n_elements (proc) ne 0)) then $
    message, "pc_read_var_raw: /reduced and 'proc' cannot be set both."
;
; Check if allprocs is set.
;
  if (keyword_set (allprocs)) then begin
    if (n_elements (proc) ne 0) then message, "pc_read_var_raw: 'allprocs' and 'proc' cannot be set both."
    if (not keyword_set (f77)) then f77=0
  end else begin
    allprocs = 0
  end
  default, f77, 1
;
; Get necessary dimensions quietly.
;
  if (n_elements (dim) eq 0) then $
      pc_read_dim, object=dim, datadir=datadir, proc=proc, reduced=reduced, /quiet
  if (n_elements (param) eq 0) then $
      pc_read_param, object=param, dim=dim, datadir=datadir, /quiet
  if (n_elements (par2) eq 0) then begin
    if (file_test (datadir+'/param2.nml')) then begin
      pc_read_param, object=par2, /param2, dim=dim, datadir=datadir, /quiet
    end else begin
      print, 'Could not find '+datadir+'/param2.nml'
    end
  end
  if (n_elements (grid) eq 0) then $
      pc_read_grid, object=grid, dim=dim, param=param, datadir=datadir, proc=proc, allprocs=allprocs, reduced=reduced, trim=trimall, /quiet
;
; Set the coordinate system.
;
  coord_system = param.coord_system
;
; Read local dimensions.
;
  nprocs = dim.nprocx * dim.nprocy * dim.nprocz
  ipx_start = 0
  ipy_start = 0
  ipz_start = 0
  if (allprocs eq 1) then begin
    procdim = dim
    ipx_end = 0
    ipy_end = 0
    ipz_end = 0
  end else begin
    ipz_end = dim.nprocz-1
    if (allprocs eq 2) then begin
      pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
      ipx_end = 0
      ipy_end = 0
      procdim.nx = dim.nxgrid
      procdim.ny = dim.nygrid
      procdim.mx = dim.mxgrid
      procdim.my = dim.mygrid
      procdim.mw = procdim.mx * procdim.my * procdim.mz
    end else begin
      if (n_elements (proc) eq 0) then begin
        pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
        ipx_end = dim.nprocx-1
        ipy_end = dim.nprocy-1
      end else begin
        pc_read_dim, object=procdim, proc=proc, datadir=datadir, /quiet
        ipx_start = procdim.ipx
        ipy_start = procdim.ipy
        ipz_start = procdim.ipz
        ipx_end = ipx_start
        ipy_end = ipy_start
        ipz_end = ipz_start
      end
    end
  end
;
; ... and check pc_precision is set for all Pencil Code tools.
;
  pc_set_precision, dim=dim, quiet=quiet
;
; Local shorthand for some parameters.
;
  nx = dim.nx
  ny = dim.ny
  nz = dim.nz
  nw = nx * ny * nz
  mx = dim.mx
  my = dim.my
  mz = dim.mz
  mw = mx * my * mz
  l1 = dim.l1
  l2 = dim.l2
  m1 = dim.m1
  m2 = dim.m2
  n1 = dim.n1
  n2 = dim.n2
  nghostx = dim.nghostx
  nghosty = dim.nghosty
  nghostz = dim.nghostz
  precision = dim.precision
;
; Initialize cdat_grid variables.
;
  t = zero
  x = fltarr (dim.mx) * one
  y = fltarr (dim.my) * one
  z = fltarr (dim.mz) * one
  if (allprocs eq 0) then begin
    x_loc = fltarr (procdim.mx) * one
    y_loc = fltarr (procdim.my) * one
    z_loc = fltarr (procdim.mz) * one
  end
  dx = zero
  dy = zero
  dz = zero
  deltay = zero
;
;  Read meta data and set up variable/tag lists.
;
  if (n_elements (varcontent) eq 0) then $
      varcontent = pc_varcontent(datadir=datadir,dim=dim,param=param,quiet=quiet)
  totalvars = (size(varcontent))[1]
  if (n_elements (var_list) eq 0) then begin
    var_list = varcontent[*].idlvar
    var_list = var_list[where (var_list ne "dummy")]
  end
;
; Display information about the files contents.
;
  content = ''
  for iv=0L, totalvars-1L do begin
    content += ', '+varcontent[iv].variable
    ; For vector quantities skip the required number of elements of the f array.
    iv += varcontent[iv].skip
  end
  content = strmid (content, 2)
;
  tags = { time:0.0d0 }
  read_content = ''
  indices = [ -1 ]
  num_read = 0
  num = n_elements (var_list)
  for ov=0L, num-1L do begin
    tag = var_list[ov]
    iv = where (varcontent[*].idlvar eq tag)
    if (iv ge 0) then begin
      if (tag eq "uu") then begin
        tags = create_struct (tags, "uu", [num_read, num_read+1, num_read+2])
        tags = create_struct (tags, "ux", num_read, "uy", num_read+1, "uz", num_read+2)
        indices = [ indices, iv, iv+1, iv+2 ]
        num_read += 3
      end else if (tag eq "aa") then begin
        tags = create_struct (tags, "aa", [num_read, num_read+1, num_read+2])
        tags = create_struct (tags, "ax", num_read, "ay", num_read+1, "az", num_read+2)
        indices = [ indices, iv, iv+1, iv+2 ]
        num_read += 3
      end else begin
        tags = create_struct (tags, tag, num_read)
        indices = [ indices, iv ]
        num_read++
      end
      read_content += ', '+varcontent[iv].variable
    end
  end
  read_content = strmid (read_content, 2)
  if (not keyword_set(quiet)) then begin
    print, ''
    print, 'The file '+varfile+' contains: ', content
    if (strlen (read_content) lt strlen (content)) then print, 'Will read only: ', read_content
    print, ''
    print, 'The grid dimension is ', dim.mx, dim.my, dim.mz
    print, ''
  end
  if (not any (indices ge 0)) then message, 'Error: nothing to read!'
  indices = indices[where (indices ge 0)]
;
; Initialise read buffers.
;
  if (precision eq 'D') then begin
    bytes = 8
    object = dblarr (dim.mx, dim.my, dim.mz, num_read)
    buffer = dblarr (procdim.mx, procdim.my, procdim.mz)
  end else begin
    bytes = 4
    object = fltarr (dim.mx, dim.my, dim.mz, num_read)
    buffer = fltarr (procdim.mx, procdim.my, procdim.mz)
  end
  if (f77 eq 0) then markers = 0 else markers = 1
;
; Iterate over processors.
;
  t = -one
  for ipz = ipz_start, ipz_end do begin
    for ipy = ipy_start, ipy_end do begin
      for ipx = ipx_start, ipx_end do begin
        iproc = ipx + ipy*dim.nprocx + ipz*dim.nprocx*dim.nprocy
        x_off = (ipx-ipx_start) * procdim.nx
        y_off = (ipy-ipy_start) * procdim.ny
        z_off = (ipz-ipz_start) * procdim.nz
        x_end = x_off + procdim.mx-1
        y_end = y_off + procdim.my-1
        z_end = z_off + procdim.mz-1
;
; Setup the coordinates mappings from the processor to the full domain.
; (Don't overwrite ghost zones of the lower processor.)
;
        x_add = nghostx * (ipx ne ipx_start)
        y_add = nghosty * (ipy ne ipy_start)
        z_add = nghostz * (ipz ne ipz_start)
;
; Build the full path and filename.
;
        if (allprocs eq 1) then begin
          if (keyword_set (reduced)) then procdir = 'reduced' else procdir = 'allprocs'
        end else begin
          procdir = 'proc' + strtrim (iproc, 2)
          if ((allprocs eq 0) and not keyword_set (quiet)) then $
              print, 'Loading chunk ', strtrim (iproc+1, 2), ' of ', strtrim (nprocs, 2)
        end
        filename = datadir+'/'+procdir+'/'+varfile
;
; Check for existence and read the data.
;
        if (not file_test (filename)) then begin
          if (arg_present (exit_status)) then begin
            exit_status = 1
            print, 'ERROR: File not found "' + filename + '"'
            close, /all
            return
          end else begin
            message, 'ERROR: File not found "' + filename + '"'
          end
        end
;
; Open a varfile and read some data!
;
        openr, lun, filename, swap_endian=swap_endian, /get_lun
        mxyz = long64 (procdim.mx) * long64 (procdim.my) * long64 (procdim.mz)
        for pos = 0, num_read-1 do begin
          pa = indices[pos]
          point_lun, lun, bytes * pa*mxyz + long64 (markers*4)
          readu, lun, buffer
          object[x_off+x_add:x_end,y_off+y_add:y_end,z_off+z_add:z_end,pos] = buffer[x_add:*,y_add:*,z_add:*]
        end
        close, lun
;
        openr, lun, filename, /f77, swap_endian=swap_endian
        point_lun, lun, bytes * dim.mvar*mxyz + long64 (2*markers*4)
        t_test = zero
        if (allprocs eq 1) then begin
          ; collectively written files
          readu, lun, t_test, x, y, z, dx, dy, dz
        end else if (allprocs eq 2) then begin
          ; xy-collectively written files for each ipz-layer
          readu, lun, t_test
          if (iproc eq 0) then readu, lun, x, y, z, dx, dy, dz
        end else begin
          ; distributed files
          if (param.lshear) then begin
            deltay = zero
            readu, lun, t_test, x_loc, y_loc, z_loc, dx, dy, dz, deltay
          end else begin
            readu, lun, t_test, x_loc, y_loc, z_loc, dx, dy, dz
          end
          x[x_off:x_end] = x_loc
          y[y_off:y_end] = y_loc
          z[z_off:z_end] = z_loc
        end
        if (t eq -one) then t = t_test
        if (t ne t_test) then begin
          print, "ERROR: TIMESTAMP IS INCONSISTENT: ", filename
          print, "t /= t_test: ", t, t_test
          print, "Type '.c' to continue..."
          stop
        end
        close, lun
        free_lun, lun
;
      end
    end
  end
;
; Tidy memory a little.
;
  undefine, buffer
  undefine, x_loc
  undefine, y_loc
  undefine, z_loc
;
; Remove ghost zones if requested.
;
  if (keyword_set (trimall)) then object = pc_noghost (object, dim=dim)
;
  if (not keyword_set (quiet)) then begin
    print, ' t = ', t
    print, ''
  endif
;
  tags.time = t
  time = t
;
end
