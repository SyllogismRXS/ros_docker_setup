ARG ROS_DISTRO=jazzy
ARG IMAGE_NAME=osrf/ros:${ROS_DISTRO}-desktop-full

FROM ${IMAGE_NAME}
LABEL org.opencontainers.image.authors="kevin.demarco@rifrobotics.com"
ENV DEBIAN_FRONTEND noninteractive
SHELL ["/bin/bash", "-c"]

RUN apt-get update \
    && apt-get install -y \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create the "ros" user, with the host user' IDs
ARG USER_ID=1000
ARG GROUP_ID=1000

# Remove the ubuntu user added by OSRF
RUN userdel ubuntu \
    && rm -rf /home/ubuntu

ENV USERNAME ros
ENV HOME_DIR /home/${USERNAME}

RUN adduser --disabled-password --gecos '' $USERNAME \
    && usermod  --uid ${USER_ID} $USERNAME \
    && groupmod --gid ${GROUP_ID} $USERNAME \
    && usermod --shell /bin/bash $USERNAME \
    && adduser $USERNAME sudo \
    && adduser $USERNAME dialout \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $USERNAME

# Run rosdep update, add ROS, Gazebo, and colcon setup to ros user's .bashrc
RUN sudo apt-get update \
    && rosdep update \
    && echo 'source /opt/ros/${ROS_DISTRO}/setup.bash' >> /home/$USERNAME/.bashrc \
    && echo 'source /usr/share/colcon_cd/function/colcon_cd.sh' >> /home/$USERNAME/.bashrc \
    && echo 'source /usr/share/colcon_cd/function/colcon_cd.sh' >> ${HOME_DIR}/.bashrc \
    && echo 'export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp' >> ${HOME_DIR}/.bashrc \
    && echo 'export RCUTILS_COLORIZED_OUTPUT=1' >> ${HOME_DIR}/.bashrc \
    && echo "export CYCLONEDDS_URI='<CycloneDDS><Domain><Discovery><ParticipantIndex>none</ParticipantIndex></Discovery></Domain></CycloneDDS>'" >> ${HOME_DIR}/.bashrc \
    && echo 'alias colcon-build="colcon build --symlink-install"' >> ${HOME_DIR}/.bashrc

# Create the workspace
RUN mkdir -p /home/$USERNAME/workspace
WORKDIR /home/$USERNAME/workspace

# Copy code into workspace, run rosdep install for workspace, build, and source setup in ros user's
COPY --chown=ros ./src src
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && sudo rosdep install --from-paths . --ignore-src -r -y --rosdistro=${ROS_DISTRO} \
    && colcon build --symlink-install \
    && echo 'source ~/workspace/install/local_setup.bash' >> /home/$USERNAME/.bashrc
