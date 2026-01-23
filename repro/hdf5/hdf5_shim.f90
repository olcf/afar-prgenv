module hdf5
  use iso_c_binding
  implicit none
  private
  public :: h5open_f, h5close_f

  interface
    integer(c_int) function H5open() bind(C, name="H5open")
      import :: c_int
    end function H5open

    integer(c_int) function H5close() bind(C, name="H5close")
      import :: c_int
    end function H5close
  end interface

contains
  subroutine h5open_f(hdferr)
    integer, intent(out) :: hdferr

    hdferr = H5open()
  end subroutine h5open_f

  subroutine h5close_f(hdferr)
    integer, intent(out) :: hdferr

    hdferr = H5close()
  end subroutine h5close_f
end module hdf5
