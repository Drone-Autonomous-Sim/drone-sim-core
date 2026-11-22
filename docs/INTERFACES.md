map                     (global fixed frame — published by SLAM / localization)
 └── odom               (drift-free local frame — published by odometry / EKF / Gazebo bridge)
      └── base_link     (drone body center: +X forward, +Y left, +Z up)
           ├── imu_link
           ├── lidar_link
           └── camera_link
                └── camera_optical_frame  (+Z forward, +X right, +Y down — OpenCV/ROS optical convention)
