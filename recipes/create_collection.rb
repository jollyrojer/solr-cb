#
# Cookbook Name:: solr-component
# Recipe:: create_collection 
#

require "pathname"

#Populate collections
if ( node["cookbook-qubell-solr"]["collection"][0].start_with?('http:','https:','ftp:','file:'))
  #if collection uri
  require 'uri'
  collection = node['cookbook-qubell-solr']['collection'][0]
  uri = URI.parse(collection)
  file_name = File.basename(uri.path)
  ext_name = File.extname(file_name)
  target_file = "/tmp/#{file_name}"

  #check is extention zip|tar.gz
  if ( ! %w{.zip .gz }.include?(ext_name))
    fail "not supported"
  end
  #download to target_file
  if ( collection.start_with?('http','ftp'))
    remote_file "#{target_file}" do
      source collection
    end
  elsif ( collection.start_with?('file'))
    target_file = URI.parse(collection).path
  end

  file_name = File.basename(target_file)
    
  #extract collection archive
  case ext_name
  when ".gz"
    bash "unpack collection #{target_file}" do
      user "root"
      code <<-EOH
      tar -xzvf #{target_file} -C #{node["cookbook-qubell-solr"]["path"]}/cores/
      chown -R #{node["tomcat"]["user"]}:#{node["tomcat"]["user"]} #{node["solr"]["path"]}/cores
      chmod -R 755 #{node["cookbook-qubell-solr"]["path"]}/cores
      EOH
    end
  when ".zip"
    package "zip" do
      action :install
    end
    bash "unpack collection #{target_file}" do
      user "root"
      code <<-EOH
       unzip -o #{target_file} -d #{node["solr"]["path"]}/cores/
      chown -R #{node["tomcat"]["user"]}:#{node["tomcat"]["user"]} #{node["cookbook-qubell-solr"]["path"]}/cores
      chmod -R 755 #{node["cookbook-qubell-solr"]["path"]}/cores
      EOH
    end
  end

  include_recipe "file"
  
  file_replace "remove hostPort in solr.xml" do
    replace 'hostPort=".*"'
    with ''
    path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
  end
  
  file_replace "remove hostContext in solr.xml" do
    replace 'hostContext=".*"'
    with ''
    path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
  end

  file_replace "remove zkHost in solr.xml" do
    replace 'zkHost=".*"'
    with ''
    path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
  end

  if (! node["cookbook-qubell-solr"]["zookeeper"]["nodes"].empty?)
    file_replace "set zkHost" do
      replace '<solr'
      with "<solr zkHost=\"#{node["cookbook-qubell-solr"]["zookeeper"]["nodes"]}\" "
      path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
    end
    file_replace "set hostPort hostContext " do
      replace '<cores'
      with "<cores hostPort=\"#{node["cookbook-qubell-solr"]["port"]}\" hostContext=\"#{node["cookbook-qubell-solr"]["hostcontext"]}\" "
      path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
    end
  else
    file_replace "set hostPort hostContext" do
      replace '<cores'
      with "<cores hostPort=\"#{node["cookbook-qubell-solr"]["port"]}\" hostContext=\"#{node["cookbook-qubell-solr"]["hostcontext"]}\" "
      path "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml"
    end
  end
else
  #If collection not uri
  #Create collections
  node["cookbook-qubell-solr"]["collection"].each do |collection|
    directory "#{node["cookbook-qubell-solr"]["path"]}/cores/#{collection}/conf/" do
      owner node["tomcat"]["user"]
      group node["tomcat"]["group"]
      mode 00755
      recursive true
      action :create
    end

    template "#{node["cookbook-qubell-solr"]["path"]}/cores/#{collection}/conf/schema.xml" do
      owner node["tomcat"]["user"]
      group node["tomcat"]["group"]
      source "schema.xml.erb"
      variables({
        :collection => "#{collection}"
      })
    end
    
    template "#{node["cookbook-qubell-solr"]["path"]}/cores/#{collection}/conf/solrconfig.xml" do
      owner node["tomcat"]["user"]
      group node["tomcat"]["group"]
      source "solrconfig.xml.erb"
      variables({
        :collection => "#{collection}"
      })
    end
  end
 
  template "#{node["cookbook-qubell-solr"]["path"]}/cores/solr.xml" do
    owner node["tomcat"]["user"]
    group node["tomcat"]["group"]
    source "solr.xml.erb"
  end
end

execute "change solr owner" do
  command "chown -R #{node["tomcat"]["user"]}:#{node["tomcat"]["group"]} #{node["cookbook-qubell-solr"]["path"]}"
end

if ( ! node["cookbook-qubell-solr"]["zookeeper"]["nodes"].empty? )
  include_recipe "cookbook-qubell-solr::zoo"
end
