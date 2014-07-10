#!/bin/sh

#YangQK and ZZR by 2013/11/21
#部署风云平台

# 0. 读取配置，初始化变量
echo "------------------------------------------------------"
echo "Initialize:Get config files"

# 0.1 初始化自定义变量
 #当前目录
CURRENT_PATH=`pwd`
 #配置文件
CONFIG_INI=$CURRENT_PATH/conf/config.ini
 #Tomcat配置文件目录
TOMCAT_CONFIG_PATH=$CURRENT_PATH/conf/tomcatConfig
 #临时文件目录
TEMP_PATH=$CURRENT_PATH/TEMP
 #生成war包目录
RELEASE_PATH=$TEMP_PATH/release
 #部署日志
LOG_FILE_INSTALL=$TEMP_PATH/install.log
 #部署错误日志
ERRORLOG_FILE_INSTALL=$TEMP_PATH/install_error.log
 #部署方式,更新还是全新部署
DEPLOY_METHOD=`awk -F '=' '/\[deploy\]/{a=1}a==1&&$1~/^deploy_method/{print $2;exit}' $CONFIG_INI`
 #ANT XML脚本
ANT_XML=`awk -F '=' '/\[ant\]/{a=1}a==1&&$1~/^ant_xml/{print $2;exit}' $CONFIG_INI`
 #SVN地址
SVN_URL=`awk -F '=' '/\[svn\]/{a=1}a==1&&$1~/^svn_url/{print $2;exit}' $CONFIG_INI`
SVN_CHECKOUT_PATH=$TEMP_PATH/code

 #TOMCAT配置
  ##节点列表,不添加到ant脚本参数中
TOMCAT_NODE_COUNT=`awk -F '=' '/\[tomcat\]/{a=1}a==1&&$1~/^tomcat_node_count/{print $2;exit}' $CONFIG_INI`
  ##节点根目录
TOMCAT_NODE_ROOTPATH=`awk -F '=' '/\[tomcat\]/{a=1}a==1&&$1~/^tomcat_node_rootpath/{print $2;exit}' $CONFIG_INI`
  ##节点名称
TOMCAT_NODE_NAME=`awk -F '=' '/\[tomcat\]/{a=1}a==1&&$1~/^tomcat_node_name/{print $2;exit}' $CONFIG_INI`

 #项目配置
  ##项目名称
PROJECT_NAME=`awk -F '=' '/\[project\]/{a=1}a==1&&$1~/^project_name/{print $2;exit}' $CONFIG_INI`
  ##项目路径
PROJECT_PATH=`awk -F '=' '/\[project\]/{a=1}a==1&&$1~/^project_path/{print $2;exit}' $CONFIG_INI`

#Add all args here,and it will be transform to the ANT scrpt
DEFINED_VARS_FOR_ANT="\
-DCURRENT_PATH=$CURRENT_PATH \
-DCONFIG_INI=$CONFIG_INI \
-DTOMCAT_CONFIG_PATH=$TOMCAT_CONFIG_PATH \
-DTEMP_PATH=$TEMP_PATH \
-DRELEASE_PATH=$RELEASE_PATH \
-DDEPLOY_METHOD=$DEPLOY_METHOD \
-DANT_XML=$ANT_XML \
-DSVN_URL=$SVN_URL \
-DSVN_CHECKOUT_PATH=$SVN_CHECKOUT_PATH \
-DTOMCAT_NODE_ROOTPATH=$TOMCAT_NODE_ROOTPATH \
-DTOMCAT_NODE_NAME=$TOMCAT_NODE_NAME \
-DPROJECT_NAME=$PROJECT_NAME \
-DPROJECT_PATH=$PROJECT_PATH \
"

# 0.2 重置安装日志
rm -rf $LOG_FILE_INSTALL


# 1. 部署环境监测
echo "------------------------------------------------------"
echo "Step1:Check install environment"

Pre_PASS=0
Pre_WARN=0
Pre_ERROR=0
Post_ERROR=0

# 1.1 检测操作系统版本
echo -n "[Pre]:Check operation system version"
OS_VERSION=`more /etc/issue|sed -n '1p'`

if [ "$OS_VERSION" = "Red Hat Enterprise Linux Server release 6.3 (Santiago)" ] ; then
    echo "                    [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
elif [ "$OS_VERSION" = "CentOS release 6.3 (Final)" ] ; then
    echo "                    [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                    [WARNING] You should install this program On REHL 6.3"
    let "Pre_WARN=$Pre_WARN+1"
fi

# 1.2 检查内存
echo -n "[Pre]:Check total memory "
MEMORY=`vmstat -s -S m|grep "total memory"|awk '{print $1}'`

if [ "$MEMORY" -gt 512 ] ; then
echo "                               [PASS]"
#let "Pre_PASS=$Pre_PASS+1"
else
echo "                               [ERROR] Install need no less 512M Memory"
#let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.3 检查剩余空间
echo -n "[Pre]:Check disk space on $TEMP_PATH "
TEMP_SPACE=`df -Pm $TEMP_PATH|sed -n '2p'|awk '{print $4}'`

if [ "$TEMP_SPACE" -gt 128 ] ; then
echo "                 [PASS]"
let "Pre_PASS=$Pre_PASS+1"
else
echo "                 [ERROR] Install need no less 128M space on $TEMP_PATH"
let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.4 检查Redis
echo -n "[Pre]:Check Redis                   "
REDIS_RUN_INFO=`netstat -anp | grep redis | grep LISTEN`

if [ "$REDIS_RUN_INFO" != "" ] ; then
    echo "                    [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                    [ERROR] Redis is not running"
    let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.4 检查MongoDB
echo -n "[Pre]:Check MongoDB            "
MONGODB_RUN_INFO=`netstat -anp | grep mongodb | grep LISTEN`

if [ "$MONGODB_RUN_INFO" != "" ] ; then
    echo "                         [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                         [ERROR] MongoDB is not running"
    let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.5 检查ActiceMQ
echo -n "[Pre]:Check ActiveMQ                   "
ACTIVEMQ_RUN_INFO=`ps -ef  | grep activemq | grep java`

if [ "$ACTIVEMQ_RUN_INFO" != "" ] ; then
    echo "                 [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                 [ERROR] ActiveMQ is not running"
    let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.6 检查MySQL
echo -n "[Pre]:Check MySQL                   "
MySQL_RUN_INFO=`netstat -anp | grep mysqld | grep LISTEN | grep tcp`

if [ "$MySQL_RUN_INFO" != "" ] ; then
    echo "                    [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                    [ERROR] MySQL is not running"
    let "Pre_ERROR=$Pre_ERROR+1"
fi

# 1.7 检查ant
echo -n "[Pre]:Check ANT                     "
ANT_ENV_INFO=`rpm -q ant|grep -v "is not installed"|wc -l`

if [ "$ANT_ENV_INFO" -gt 0 ] ; then
    echo "                    [PASS]"
    let "Pre_PASS=$Pre_PASS+1"
else
    echo "                    [ERROR] ANT is not installed"
    let "Pre_ERROR=$Pre_ERROR+1"
fi


# 检查结果
echo "Check Summary:[PASS:$Pre_PASS][WARNING:$Pre_WARN][ERROR:$Pre_ERROR]"

if [ $Pre_ERROR -gt 0 ] ; then
    echo -n "There are errors in environment check. Will you continue?[Y/N(Default)]:"
    read IGNORE_ERROR

    if [[ $IGNORE_ERROR != "Y" && $IGNORE_ERROR != "y" ]] ; then
        exit 1
    fi
fi

# 2. 部署Java服务
echo "------------------------------------------------------"
echo "Step2:Rebuild Tomcat Service"

# 2.1 从SVN检出代码
echo -n "[svn]:Get code from svn:"
if [ -d "$SVN_CHECKOUT_PATH" ]; then
    if [ "$DEPLOY_METHOD" = "rebuild" ]; then
        echo -n "Update Code:" > $LOG_FILE_INSTALL 
        echo "                                                                    [FINISH]"
    	cd $SVN_CHECKOUT_PATH
    	svn up 1>$LOG_FILE_INSTALL
    else
        echo -n "Delete old code folder and check out new code:"
        rm -rf $SVN_CHECKOUT_PATH
        svn co $SVN_URL $SVN_CHECKOUT_PATH 1>$LOG_FILE_INSTALL
        echo "                      [FINISH]"
    fi
else
    echo Check out code:
    echo -n "svn co $SVN_URL $SVN_CHECKOUT_PATH"
    svn co $SVN_URL $SVN_CHECKOUT_PATH 1>$LOG_FILE_INSTALL
fi

# 2.2 删除code下WebRoot/WEB-INF/classes目录的文件
echo -n "[file]:Delete $SVN_CHECKOUT_PATH/WebRoot/WEB-INF/classes/"
rm -rf $SVN_CHECKOUT_PATH/WebRoot/WEB-INF/classes/*
echo "                                    [FINISH]"

# 2.3 删除release下的文件
echo -n "[file]:Delete $RELEASE_PATH/*"
rm -rf $RELEASE_PATH/*
mkdir -p $RELEASE_PATH
echo "                                                        [FINISH]"

# 2.5 复制配置文件到需要编译的源码中
echo -n "[file]:Copy $TOMCAT_CONFIG_PATH/config.properties $SVN_CHECKOUT_PATH/src/config"
rm -rf $SVN_CHECKOUT_PATH/src/config/*
cp $TOMCAT_CONFIG_PATH/config.properties $SVN_CHECKOUT_PATH/src/config/
cp $TOMCAT_CONFIG_PATH/jdbc.properties $SVN_CHECKOUT_PATH/src/config/
echo "        [FINISH]"

# 2.6 编译java,并打包成war文件用于tomcat
echo -n "[file]:Compile java source code"
cd $CURRENT_PATH
ant -buildfile $ANT_XML $DEFINED_VARS_FOR_ANT 1>$LOG_FILE_INSTALL
echo "                                                             [FINISH]"


# 3. 重启Java服务
echo "------------------------------------------------------"
echo "Step3:Restart Tomcat Service"

for i in ${TOMCAT_NODE_COUNT}
do
    echo -n "[tomcat]:restart ${TOMCAT_NODE_NAME}$i"

    #运行脚本关闭tomcat
    NODE_RUN_INFO=`ps -ef | grep ${TOMCAT_NODE_NAME}$i | grep tomcat`
    if [ "$NODE_RUN_INFO" != "" ] ; then
        sh ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/bin/shutdown.sh 1>$LOG_FILE_INSTALL;
        sleep 5 
    fi

    #如果shutdown脚本未正常运行,则强行关闭程序
    NODE_RUN_INFO=`ps -ef | grep ${TOMCAT_NODE_NAME}$i | grep tomcat`
    if [ "$NODE_RUN_INFO" != "" ] ; then
        kill -9 $(ps -ef | grep 'tomcat' | grep ${TOMCAT_NODE_NAME}$i | awk '{printf $2}') 1>$LOG_FILE_INSTALL
        sleep 5
    fi

    # 删除原始的war包
    rm -rf  ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/webapps/${PROJECT_NAME};
    rm -rf  ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/webapps/${PROJECT_NAME}.war;
    if [ -d "${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/webapps/${PROJECT_NAME}" ]; then
        echo "             [FAILED]"
        continue
    else
        cp $RELEASE_PATH/${PROJECT_NAME}.war ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/webapps/${PROJECT_NAME}.war 	
    fi 

    # 更新tomcat配置
    rm -rf ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/conf/server.xml
    cp $TOMCAT_CONFIG_PATH/${TOMCAT_NODE_NAME}$i/server.xml ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/conf/
    rm -rf ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/conf/web.xml    
    cp $TOMCAT_CONFIG_PATH/${TOMCAT_NODE_NAME}$i/web.xml ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/conf/
    rm -rf ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/bin/catalina.sh
    cp $TOMCAT_CONFIG_PATH/catalina.sh $TOMCAT_NODE_ROOTPATH/${TOMCAT_NODE_NAME}$i/bin/

    #启动tomcat
    #rm -rf /tomcat/Node1/logs/*;
    sh ${TOMCAT_NODE_ROOTPATH}/${TOMCAT_NODE_NAME}$i/bin/startup.sh 1>$LOG_FILE_INSTALL;
    
    NODE_RUN_INFO=`ps -ef | grep ${TOMCAT_NODE_NAME}$i | grep tomcat`
    if [ "$NODE_RUN_INFO" != "" ] ; then
        echo "             [FINISH]"
    else
        echo "             [FAILED]"
    fi
done
