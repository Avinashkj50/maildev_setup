  #!/bin/bash
    echo "
 ###########################################################################
 ##  Automation script that deploys a fake smtp server (maildev) on Linux ##
 ##  by identifying the package manager (yum/apt)                         ##
 ###########################################################################
    "
 
  #Fetch current package manager 
    YUM_CMD=$(which yum)
    APT_GET_CMD=$(which apt-get)
    
  #Create maildev log file on specific path
    home_path="$(eval echo ~$USER)"    
    log_file="$home_path/maildev.log"
    touch $log_file

  #mail address to send alert mail
    alert_mail='avinashkj50@gmail.com'  

  #Function to deploy maildev
  install_maildev() {

    echo "********** Installing maildev server/package as node app **********"
    maildev_check=$(npm list -g --depth=0 | grep 'maildev@')
    
    if [[ -z "$maildev_check" ]]; then   
        sudo npm install -g maildev
    else
        echo -e "      > MailDev already installed, maildev_version: $(maildev --version) \n" 
    fi
  }
  
  #Prerequisites and dependency packages
  #check npm is installed or not (node.js)  
    echo "********** Installing dependency packages (npm - node.js) **********"
  if [[ -n "$YUM_CMD" ]]; then
     
        npm_check=$(rpm -qa | grep npm)
        if [[ -z "$npm_check" ]]; then 
            sudo yum install dnf -y &> /dev/null
            sudo dnf install npm 
        else 
            echo -e "      > npm - already installed, npm_version: $(npm --version) \n" 
        fi

  elif [[ -n "$APT_GET_CMD" ]]; then
       
       sudo apt install dpkg -y &> /dev/null
        dpkg -s npm &> /dev/null
          if [[ $? -ne 0 ]]; then 
            sudo apt install npm -y
          else 
            echo -e "      > npm - already installed, npm_version: $(npm --version) \n"   
          fi      
  else 
        echo -e "      > This scripts only support for yum/apt package manager\n"
        exit 1
  fi

    #function call to install maildev as node app
        install_maildev
 
    #Create maildev_cron script file 
        cron_file="/usr/local/bin/md_cron.sh"
        sudo touch $cron_file
        sudo chmod 777 $cron_file

cron_script() {
sudo cat > "$cron_file" << EOF
#!/bin/bash
    if [[ -z "\$(nc -w2 -i2 0.0.0.0 1025)" ]]; then
        echo "      > Starting maildev deamon service"
        nohup maildev > $log_file 2>&1 &
        sleep 10
        if  [[ -n "\$(nc -w2 -i2 0.0.0.0 1025)" ]]; then
            echo -e "         - maildev service successfully started\n"
        else
            if [[ -z "\$(ps aux | awk '\$12=="/usr/local/bin/maildev"')" ]]; then
                echo -e "         - maildev service failed to start\n"
                mail -s "This is the subject" $alert_mail <<< 'Cron job failed to start maildev service'
            fi
        fi
    else
        echo -e "      > mail service is already running\n"
        touch /home/harsha/Desktop/running_md
    fi  
EOF
}

  

    
    #Running maildev Deamon in background and redirecting output to user specific log file
        echo "********** Checking maildev cron job **********" 
       cron_job=$(crontab -l | grep 'md_cron')
        if [[ -n "$cron_job" ]]; then 
            echo "      > crontab job is set for every 5 minutes"
        else 
            echo "      > setting crontab job run on every 5 minutes for below:"
            echo "         * checks if maildev server is running or not"
            echo "         * if maildev server is not running, start maildev"
            echo "         * cron script file: $cron_file"
                cron_script
            crontab -l | { cat; echo "*/5 * * * * /bin/bash $cron_file"; } | crontab -
            if [[ -n "$YUM_CMD" ]]; then
                echo "         - Restarting cron service ...." 
                sudo systemctl restart crond.service
            elif [[ -n "$APT_GET_CMD" ]]; then
                echo "         - Restarting cron service ...."   
                sudo service cron restart
            fi
            cron_job_check=$(crontab -l | grep 'md_cron')
            [[ -n "$cron_job_check" ]] && echo "         - new crontab entry added" || echo "         - failed to add new crontab entry"
        fi
            

