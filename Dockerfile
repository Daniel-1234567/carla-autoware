ARG AUTOWARE_VERSION=1.14.0-melodic-cuda

FROM autoware/autoware:$AUTOWARE_VERSION

WORKDIR /home/autoware

# Update simulation repo to latest master.
COPY --chown=autoware update_sim.patch ./Autoware
RUN patch ./Autoware/autoware.ai.repos ./Autoware/update_sim.patch
RUN cd ./Autoware \
    && vcs import src < autoware.ai.repos \
    && git --git-dir=./src/autoware/simulation/.git --work-tree=./src/autoware/simulation pull \
    && source /opt/ros/melodic/setup.bash \
    && AUTOWARE_COMPILE_WITH_CUDA=1 colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# CARLA PythonAPI
RUN mkdir ./PythonAPI
ADD --chown=autoware https://carla-releases.s3.eu-west-3.amazonaws.com/Backup/carla-0.9.10-py2.7-linux-x86_64.egg ./PythonAPI
RUN echo "export PYTHON2_EGG=$(ls /home/autoware/PythonAPI | grep py2.)" >> .bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:~/PythonAPI/\$PYTHON2_EGG" >> .bashrc

# CARLA ROS Bridge
# There is some kind of mismatch between the ROS debian packages installed in the Autoware image and
# the latest ros-melodic-ackermann-msgs and ros-melodic-derived-objects-msgs packages. As a
# workaround we use a snapshot of the ROS apt repository to install an older version of the required
# packages. 
RUN sudo rm -f /etc/apt/sources.list.d/ros1-latest.list

# Todo: fix the key errors

#RUN apt-key del 4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA
#RUN sudo -E  apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

#RUN sudo apt-key del 7fa2af80


# To solve the key's issue, I refered to the discussion: https://forums.developer.nvidia.com/t/gpg-error-http-developer-download-nvidia-com-compute-cuda-repos-ubuntu1804-x86-64/212904/3

RUN sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/3bf863cc.pub

#RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key AD19BAB3CBF125EA
# RUN sudo apt install curl
# RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -

RUN sudo sh -c 'echo "deb http://snapshots.ros.org/melodic/2020-08-07/ubuntu $(lsb_release -sc) main" >> /etc/apt/sources.list.d/ros-snapshots.list'
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        python-pip \
        python-wheel \
        ros-melodic-ackermann-msgs \
        ros-melodic-derived-object-msgs \
    && sudo rm -rf /var/lib/apt/lists/*
# RUN sudo apt-get install -y --no-install-recommends \
#         python-pip \
#         python-wheel \
#         ros-melodic-ackermann-msgs \
#         ros-melodic-derived-object-msgs \
#     && sudo rm -rf /var/lib/apt/lists/*


RUN pip install simple-pid pygame networkx==2.2

RUN git clone -b '0.9.10.1' --recurse-submodules https://github.com/carla-simulator/ros-bridge.git

# CARLA Autoware agent
COPY --chown=autoware . ./carla-autoware

RUN mkdir -p carla_ws/src
RUN cd carla_ws/src \
    && ln -s ../../ros-bridge \
    && ln -s ../../carla-autoware/carla-autoware-agent \
    && cd .. \
    && source /opt/ros/melodic/setup.bash \
    && catkin_make

RUN echo "export CARLA_AUTOWARE_CONTENTS=~/autoware-contents" >> .bashrc \
    && echo "source ~/carla_ws/devel/setup.bash" >> .bashrc \
    && echo "source ~/Autoware/install/setup.bash" >> .bashrc

CMD ["/bin/bash"]

