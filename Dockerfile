FROM centos:centos6.6

MAINTAINER Michael Stealey <michael.j.stealey@gmail.com>

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres

ENV TERM xterm

RUN echo -e "\
[EPEL]\n\
name=Extra Packages for Enterprise Linux \$releasever - \$basearch\n\
#baseurl=http://download.fedoraproject.org/pub/epel/\$releasever/\$basearch\n\
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-\$releasever&arch=\$basearch\n\
failovermethod=priority\n\
enabled=1\n\
gpgcheck=0\n\
" >> /etc/yum.repos.d/epel.repo
RUN rpm -ivh http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm && \
    yum install -y postgresql93 postgresql93-server postgresql93-odbc unixODBC pwgen hostname  sudo && \
	yum clean all

ADD setup-postgresql.sh /setup-postgresql.sh 

ENTRYPOINT ["/setup-postgresql.sh"]