FROM centos:centos6.6

MAINTAINER Michael Stealey <michael.j.stealey@gmail.com>

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres

ENV TERM xterm

RUN yum install -y wget
RUN wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
RUN rpm -Uvh epel-release-6*.rpm
RUN rpm -ivh http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm
RUN yum install -y postgresql93 postgresql93-server postgresql93-odbc unixODBC
RUN yum install -y hostname sudo pwgen

ADD setup-postgresql.sh /setup-postgresql.sh 

ENTRYPOINT ["/setup-postgresql.sh"]