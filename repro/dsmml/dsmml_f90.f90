program dsmml_test
  use, intrinsic :: iso_c_binding
  implicit none

  interface
    integer(c_int) function dsmml_get_version_info(major, minor) bind(C, name="dsmml_get_version_info")
      use, intrinsic :: iso_c_binding
      integer(c_int), intent(out) :: major
      integer(c_int), intent(out) :: minor
    end function dsmml_get_version_info
  end interface

  integer(c_int) :: major, minor
  integer(c_int) :: rc

  rc = dsmml_get_version_info(major, minor)
end program dsmml_test
