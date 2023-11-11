include /usr/include/mrbuild/Makefile.common.header

PROJECT_NAME := multisense

# Comes from CPACK_PACKAGE_VERSION in multisense_lib/sensor_api/CMakeLists.txt
ABI_VERSION  := 6
TAIL_VERSION := 1.0

LIB_SOURCES +=									\
  multisense_lib/sensor_api/source/LibMultiSense/details/dispatch.cc		\
  multisense_lib/sensor_api/source/LibMultiSense/details/utility/Exception.cc	\
  multisense_lib/sensor_api/source/LibMultiSense/details/utility/TimeStamp.cc	\
  multisense_lib/sensor_api/source/LibMultiSense/details/utility/Constants.cc	\
  multisense_lib/sensor_api/source/LibMultiSense/details/constants.cc		\
  multisense_lib/sensor_api/source/LibMultiSense/details/flash.cc		\
  multisense_lib/sensor_api/source/LibMultiSense/details/public.cc		\
  multisense_lib/sensor_api/source/LibMultiSense/details/channel.cc		\
  multisense_ros/src/pps.cpp							\
  multisense_ros/src/camera.cpp							\
  multisense_ros/src/statistics.cpp						\
  multisense_ros/src/status.cpp							\
  multisense_ros/src/imu.cpp							\
  multisense_ros/src/laser.cpp							\
  multisense_ros/src/reconfigure.cpp						\
  multisense_ros/src/camera_utilities.cpp					\
  multisense_ros/src/ground_surface_utilities.cpp				\
  multisense_ros/src/point_cloud_utilities.cpp

# Things with main()
BIN_SOURCES +=					\
  multisense_ros/src/raw_snapshot.cpp		\
  multisense_ros/src/color_laser.cpp		\
  multisense_ros/src/ros_driver.cpp

BIN_SOURCES +=												\
  multisense_lib/sensor_api/source/Utilities/AprilTagTestUtility/AprilTagTestUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/ChangeFps/ChangeFps.cc					\
  multisense_lib/sensor_api/source/Utilities/ChangeIpUtility/ChangeIpUtility.cc				\
  multisense_lib/sensor_api/source/Utilities/ChangeResolution/ChangeResolution.cc			\
  multisense_lib/sensor_api/source/Utilities/ChangeTransmitDelay/ChangeTransmitDelay.cc			\
  multisense_lib/sensor_api/source/Utilities/ColorImageUtility/ColorImage.cc				\
  multisense_lib/sensor_api/source/Utilities/DeviceInfoUtility/DeviceInfoUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/ExternalCalUtility/ExternalCalUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/FlashUtility/FlashUtility.cc				\
  multisense_lib/sensor_api/source/Utilities/ImageCalUtility/ImageCalUtility.cc				\
  multisense_lib/sensor_api/source/Utilities/ImuConfigUtility/ImuConfigUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/ImuTestUtility/ImuTestUtility.cc				\
  multisense_lib/sensor_api/source/Utilities/LidarCalUtility/LidarCalUtility.cc				\
  multisense_lib/sensor_api/source/Utilities/PointCloudUtility/PointCloudUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/RectifiedFocalLengthUtility/RectifiedFocalLengthUtility.cc	\
  multisense_lib/sensor_api/source/Utilities/SaveImageUtility/SaveImageUtility.cc			\
  multisense_lib/sensor_api/source/Utilities/VersionInfoUtility/VersionInfoUtility.cc

# non-ros stuff
LDLIBS +=					\
  -lturbojpeg					\
  -lopencv_core					\
  -lopencv_imgproc				\
  -lopencv_calib3d

# ros stuf
LDLIBS +=					\
  -lroscpp					\
  -lrosconsole					\
  -lroscpp_serialization			\
  -lrostime					\
  -limage_transport				\
  -ltf2_ros					\
  -lrosbag_storage				\
  -ldynamic_reconfigure_config_init_mutex	\
  -lconsole_bridge

# I must set up dependendies on generated files manually. I don't want to deeply
# figure out what all the .o files are that transitively include the generated
# headers, so I make ALL .o files depend on these
ALL_O_FILES := $(addsuffix .o,$(basename $(LIB_SOURCES)) \
                              $(basename $(BIN_SOURCES)) )

ALL_GENERATED_CONFIG_H      := $(shell awk -F'[<>]' '/include.*Config.h/ {print $$2}'  multisense_ros/include/multisense_ros/reconfigure.h)
ALL_GENERATED_CONFIG_H_NO_M := $(addprefix ultisense_ros/include/,$(ALL_GENERATED_CONFIG_H))
ALL_GENERATED_CONFIG_H      := $(addprefix m,$(ALL_GENERATED_CONFIG_H_NO_M))

$(ALL_O_FILES): $(ALL_GENERATED_CONFIG_H)


# Set the ROS_ROOT. The OSRF packages already set this, but they do it wrong: I
# want /opt/ros/noetic, not /opt/ros/noetic/share/ros
ifeq ($(ROS_DISTRO),)
  ROS_ROOT := /usr
else
  ROS_ROOT := /opt/ros/$(ROS_DISTRO)
endif

# I'm writing a bunch of files from one command. The nice way to communicate
# this fact to Make is to use group prerequisites. Like this:
#
#   $(ALL_GENERATED_CONFIG_H) &: multisense_ros/cfg/multisense.cfg
#
# But they appeared in GNU Make 4.3, which isn't shipped with Ubuntu 20.04,
# which I'm targeting. So instead I do it the old-fashioned way: using pattern
# rules. There isn't a pattern here, so I do it in a hacky way: the initial "m"
# is the wildcard in the pattern
$(addprefix %,$(ALL_GENERATED_CONFIG_H_NO_M)): %ultisense_ros/cfg/multisense.cfg
	python3 \
	  $< \
	  $(ROS_ROOT)/share/dynamic_reconfigure \
	  BINARY_DIR_UNUSED \
	  $(dir $@) \
	  PYTHON_GEN_DIR_UNUSED
# I clean out ALL the Config.h. I could have generated some that
# ALL_GENERATED_CONFIG_H doesn't contain
EXTRA_CLEAN += multisense_ros/include/multisense_ros/*Config.h BINARY_DIR_UNUSED PYTHON_GEN_DIR_UNUSED

# All .o files depend on all the message definitions that we have. Tighter
# dependencies are possible, but require manual work


ALL_GENERATED_MSG_H := $(patsubst multisense_ros/msg/%.msg,multisense_ros/include/multisense_ros/%.h,$(wildcard multisense_ros/msg/*.msg))
$(ALL_O_FILES): $(ALL_GENERATED_MSG_H)
multisense_ros/include/multisense_ros/%.h: multisense_ros/msg/%.msg
	python3 \
	  $(ROS_ROOT)/lib/gencpp/gen_cpp.py \
	  $< \
	  -Imultisense_ros:multisense_ros/msg \
	  -Isensor_msgs:$(ROS_ROOT)/share/sensor_msgs/msg \
	  -Igeometry_msgs:$(ROS_ROOT)/share/geometry_msgs/msg \
	  -Istd_msgs:$(ROS_ROOT)/share/std_msgs/msg \
	  -p multisense_ros \
	  -o multisense_ros/include/multisense_ros/ \
	  -e $(ROS_ROOT)/share/gencpp
EXTRA_CLEAN += $(ALL_GENERATED_MSG_H)



CCXXFLAGS += -Wno-missing-field-initializers -Wno-unused-variable -Wno-unused-parameter
CCXXFLAGS += -std=c++17
CCXXFLAGS += -DCRL_HAVE_GETOPT=1

CCXXFLAGS +=							\
  -Imultisense_ros/include					\
  -Imultisense_lib/sensor_api/source/LibMultiSense/include	\
  -Imultisense_lib/sensor_api/source				\
  -I/usr/include/eigen3/					\
  -I/usr/include/opencv4

# For ROS
ifeq ($(ROS_DISTRO),)
  # Using the vanilla Debian packages
  CXXFLAGS += \
    -I/usr/include/pluginlib \
    -I/usr/include/class_loader \
    -I/usr/include/rcutils \
    -I/usr/include/rcpputils \
    -I/usr/include/ament_index_cpp \
    -I/usr/include/angles
else
  # OSRF packages
  CXXFLAGS += \
    -I$(ROS_ROOT)/include

  LDFLAGS += $(addprefix -L,$(LD_LIBRARY_PATH))
endif

include /usr/include/mrbuild/Makefile.common.footer
