#!/bin/bash

set -e

# Apply a patch if not already applied
function try_apply_patch {
  PATCH_TARGET_DIR=$1
  PATCH_FILE_LOC=$2

  pushd $PATCH_TARGET_DIR >/dev/null
  # Check if the patch has already been applied or not
  set +e
  patch -p1 -N --dry-run --silent < $PATCH_FILE_LOC 2>/dev/null
  if [ $? -eq 0 ]; then
    patch -p1 -N < $PATCH_FILE_LOC
  fi
  set -e
  popd >/dev/null
}

CROSS_COMPILE=aarch64-linux-gnu-
PROJECT_ROOT=`pwd`
ROS_ARM_ROOT=$PROJECT_ROOT/deps/ros2_arm64

if [ -z "$CROSS_COMPILE" ]; then
  echo ""
  echo "ERROR: Define CROSS_COMPILE with the location of the cross-compilation compiler."
  echo "e.g."
  echo "export CROSS_COMPILE=aarch64-linux-gnu-"
  echo ""
fi

mkdir -p $ROS_ARM_ROOT/src
pushd $ROS_ARM_ROOT >/dev/null

# Download ROS2 code
if [ ! -f aarch64_toolchainfile.cmake ]; then
  wget https://raw.githubusercontent.com/ros2/ros2/release-latest/ros2.repos
  wget https://raw.githubusercontent.com/ros2-for-arm/ros2/master/ros2-for-arm.repos
  wget https://raw.githubusercontent.com/ros2-for-arm/ros2/master/aarch64_toolchainfile.cmake
  vcs-import src < ros2.repos
  vcs-import src < ros2-for-arm.repos
  echo "update cmake file..."
  echo "set(PATH_POCO_LIB \"\${CMAKE_CURRENT_LIST_DIR}/build/poco_vendor/poco_external_project_install/lib/\")" >> aarch64_toolchainfile.cmake
  echo "set(PATH_YAML_LIB \"\${CMAKE_CURRENT_LIST_DIR}/build/libyaml_vendor/libyaml_install/lib/\")" >> aarch64_toolchainfile.cmake
  echo "set(CMAKE_BUILD_RPATH \"\${PATH_POCO_LIB};\${PATH_YAML_LIB}\")" >> aarch64_toolchainfile.cmake
fi

# Ignore select ROS packages
# NB: Currently ignores RCLPY -- the console ros2 applications won't work
#                                without this but the C++ interface is fine
sed -i \
  -r \
  's/<build(.+?py.+?)/<\!\-\-build\1\-\->/' \
  src/ros2/rosidl_defaults/rosidl_default_generators/package.xml
touch \
  src/ros/resource_retriever/COLCON_IGNORE \
  src/ros2/demos/COLCON_IGNORE \
  src/ros2/examples/rclpy/COLCON_IGNORE \
  src/ros2/geometry2/COLCON_IGNORE \
  src/ros2/kdl_parser/COLCON_IGNORE \
  src/ros2/orocos_kinematics_dynamics/COLCON_IGNORE \
  src/ros2/rclpy/COLCON_IGNORE \
  src/ros2/rcl_interfaces/test_msgs/COLCON_IGNORE \
  src/ros2/rmw_connext/COLCON_IGNORE \
  src/ros2/rmw_opensplice/COLCON_IGNORE \
  src/ros2/robot_state_publisher/COLCON_IGNORE \
  src/ros2/ros1_bridge/COLCON_IGNORE \
  src/ros2/rosidl_python/COLCON_IGNORE \
  src/ros2/rviz/COLCON_IGNORE \
  src/ros2/system_tests/COLCON_IGNORE \
  src/ros2/urdf/COLCON_IGNORE \
  src/ros2/urdfdom/COLCON_IGNORE \
  src/ros2/rcl/rcl/test/COLCON_IGNORE \
  src/ros2/examples/COLCON_IGNORE \
  src/ros2-for-arm/example/COLCON_IGNORE \
  src/ros-perception/laser_geometry/COLCON_IGNORE

# Patch ROS packages
try_apply_patch \
  src/ros2/tlsf/tlsf \
  $PROJECT_ROOT/tlsf_CMakeLists.patch
try_apply_patch \
  src/ros2/tlsf/tlsf \
  $PROJECT_ROOT/tlsf_package.patch

# For some reason, libyaml needs to be built first otherwise cmake doesn't
# find it
colcon build \
  --packages-up-to libyaml_vendor \
  --symlink-install \
  --cmake-force-configure \
  --cmake-args \
    " -DCMAKE_TOOLCHAIN_FILE=`pwd`/aarch64_toolchainfile.cmake" \
    " -DTHIRDPARTY=ON" \
    " -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" \
    " -DBUILD_SHARED_LIBS=OFF" \
    " -DCOMPILE_EXAMPLES=OFF" \
    " -DCMAKE_C_STANDARD=99" \
    " -DBUILD_TESTING:BOOL=OFF"
# Build the rest
colcon build \
  --packages-skip libyaml_vendor \
  --symlink-install \
  --cmake-force-configure \
  --cmake-args \
    " -DCMAKE_TOOLCHAIN_FILE=`pwd`/aarch64_toolchainfile.cmake" \
    " -DTHIRDPARTY=ON" \
    " -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" \
    " -DBUILD_SHARED_LIBS=OFF" \
    " -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON" \
    " -DCOMPILE_EXAMPLES=OFF" \
    " -DCMAKE_C_STANDARD=99" \
    " -DBUILD_TESTING:BOOL=OFF"
