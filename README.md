# spring-boot-run

## 简介
该项目是为了解决Spring Boot程序主机部署运行的问题

### app_env.conf
该文件是run.sh的参数文件，run.sh会引用此文件，里面的参数只供run.sh使用，不设置为环境变量（避免污染环境变量）


### run.sh
该脚本用来运行Spring Boot应用，动态内容抽到了app_env.conf,所以这个脚本内容一般不会进行修改，程序部署时可以直接拷贝，根据
服务的实际情况修改app_env.conf即可

#### 功能
1. 启动
2. 关闭
3. 状态
4. 重启
