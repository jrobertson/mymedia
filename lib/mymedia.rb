#!/usr/bin/env ruby

# file: mymedia.rb

require 'time'
require 'fileutils'
require 'logger'
require 'dynarex'
require 'sps-pub'
require 'dir-to-xml'
require 'dataisland'
require 'increment'


module MyMedia
  
  class Publisher
    
    def publish_dynarex(dynarex_filepath='', \
          record={title: '',url: '', raw_url: ''}, options={})
      
      opt = {id: nil, rss: false}.merge(options)
      
      dynarex = if File.exists? dynarex_filepath then
        Dynarex.new(dynarex_filepath)
      else
        Dynarex.new(@schema)
      end

      dynarex.create record, opt[:id]
      dynarex.save dynarex_filepath
      publish_html(dynarex_filepath)    

      
      if opt[:rss] == true then
        
        dynarex.xslt_schema = dynarex.summary[:xslt_schema]
        rss_filepath = dynarex_filepath.sub(/\.xml$/,'_rss.xml')
        File.open(rss_filepath, 'w'){|f| f.write dynarex.to_rss }    
      end

    end

    def publish_html(filepath)
      
      path2 = File.dirname(filepath)  

      dataisland = DataIsland.new(path2 + '/index-template.html')
      File.open(path2 + '/index.html','w'){|f| f.write dataisland.html_doc.xml pretty: true}
    end    
    
  end
  
  class Base < Publisher

    attr_reader :to_s

    def initialize(media_type: 'blog', public_type: 'blog', ext: 'txt', config: nil)

      super()
      @schema = 'posts/post(title, url, raw_url)'
      @logger = Logger.new('/tmp/mymedia.log','daily')

      @home = config[:home]
      @website = config[:website]    
      @dynamic_website = config[:dynamic_website]
      @www = config[:www]
      @domain = @website[/[^\.]+\.[^\.]+$/]

      @sps = config[:sps]
      
      @media_type = media_type
      @public_type = public_type ||= @media_type
      
      @xslt_schema = 'channel[title:title,description:desc]/' + \
                                                'item(title:title,link:url)'
      @ext = ext
      @rss = false
      Dir.chdir @home
    end
        
    def add_feed_item(raw_msg, record, options={})
      
      dynarex_filepath = File.join([@home, @public_type, 'dynarex.xml'])        
      id = Increment.update(File.join([@home, @public_type, 'counter.txt'])) 
      static_url = @static_baseurl + id
      record[:uri] = static_url
      
      publish_dynarex(dynarex_filepath, record, {id: id}.merge(options))                    
      publish_timeline(raw_msg, static_url)         
      publish_html(@home + '/index.html') 
    end

    def auto_copy_publish(raw_msg='')

      filename = DirToXML.new(@media_src).select_by_ext(@ext)\
        .sort_by(:last_modified).last[:name]  
      copy_publish( filename ,raw_msg)
    end
    
    def copy_publish(filename, raw_msg='')
      file_publish(File.join(@media_src,filename), raw_msg)
    end
        

    private
    
    def file_publish(src_path, raw_msg='')
        
      raise @logger.debug("source file not found") unless File.exists? src_path
      ext = File.extname(src_path)
      @target_ext ||= ext
          
      public_path = "%s/%s/%shrs%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, Time.now.strftime('%H%M'), 
                                      @target_ext]
      public_path2 = "%s/%s/%shrs%s%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, Time.now.strftime('%H%M'), 
                                          Time.now.strftime('%S%2N'), @target_ext]
      
      raw_destination = "%s/%s/%s" % [@home, 'r', public_path]
      
      if File.exists? raw_destination then
        raw_destination = "%s/%s/%s" % [@home, 'r', public_path2]
        public_path = public_path2
      end

      destination = "%s/%s" % [@home, public_path]
      FileUtils.mkdir_p File.dirname(raw_destination)
      FileUtils.mkdir_p File.dirname(destination)

      raw_msg = raw_msg.join if raw_msg.is_a? Array

      raw_msg = src_path[/([^\/]+)\.\w+$/,1] + ' ' + raw_msg if raw_msg
      
      
      if block_given? then
        raw_msg, target_url = yield(destination, raw_destination) 
        static_url = target_url
      else
        FileUtils.cp src_path, destination
        FileUtils.cp src_path, raw_destination
      end
      

      raw_msg = raw_msg.join if raw_msg.is_a? Array   
      
      static_filename = if raw_msg.length > 0 then
        normalize(raw_msg) + File.extname(destination)    
      else
        File.basename(src_path)
      end
      
      static_path = "%s/%s/%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, static_filename]
      
      raw_static_destination = "%s/%s/%s" % [@home, 'r',static_path]

      static_destination = "%s/%s" % [@home, static_path]    
      FileUtils.cp destination, static_destination
      FileUtils.cp raw_destination, raw_static_destination
      
      target_url ||= "%s/%s" % [@website, public_path]
      static_url ||= "%s/%s" % [@website, static_path]

      if raw_msg.length > 0 then
        msg = "%s %s" % [target_url, raw_msg ]
      else
        msg = "the %s %s %s" % [notice, @public_type.sub(/s$/,''), target_url]
      end
      
      sps_message = [@sps[:default_subscriber] + ': publish', @public_type, 
                    target_url, static_url, "'" + raw_msg + "'"]            

      topic, msg = sps_message.join(' ').split(/:\s*/,2)
      send_message(topic: topic, msg: msg)

      static_url
      
    end
    
    def normalize(s)
      r = s.downcase.gsub(/\s#\w+/,'').strip.gsub(/\W/,'-').gsub(/-{2,}/,'-').gsub(/^-|-$/,'')
      return s.scan(/#(\w+)/)[0..1].join('_').downcase if r.empty?
      return r        
    end        
    
    def notice()
      
      case 
        when Time.now.hour < 10
          "morning"
        when Time.now.hour < 12
          "late morning"        
        when Time.now.hour >= 12 && Time.now.hour <= 13
          "lunch time"
        when Time.now.hour > 13 &&  Time.now.hour < 16
          "afternoon"
        when Time.now.hour < 18
          "late afternoon"        
        when Time.now.hour >= 18
          "evening"
      end
    end
    
    def send_message(topic: @sps[:default_subscriber], msg: msg)
      
      fqm = "%s: %s" % [topic, msg]    
      SPSPub.notice fqm, address: @sps[:address]
    end

  end
  
  class Frontpage < Publisher
    
    def initialize(conf: nil, public_type: '', rss: nil)
      
      @home = conf[:home]
      @public_type = public_type
      @rss = rss
      
      @logger = Logger.new('/tmp/mymedia.log','daily')
    end
    
    def publish_frontpage(s='index.html')    
      publish_html(@home + '/' + s) 
      'frontpage published'
    end  

        
    def publish_to_lists(record={}, public_type=nil)
      
      @public_type = public_type if public_type

      raw_msg, static_url, target_url = \
          record[:title], record[:url], record[:static_url]
      dynarex_filepath = "%s/%s/dynarex.xml" % [@home, @public_type]
      raw_dynarex_filepath = "%s/r/%s/dynarex.xml" % [@home, @public_type]
      
      publish_dynarex(dynarex_filepath, record, {rss: @rss || false})    
      publish_dynarex(raw_dynarex_filepath, record, {rss: @rss || false})          
      publish_timeline(raw_msg, static_url, target_url)         
 
    end

    
    def publish_timeline(raw_msg, static_url, target_url='')
      
      timeline_filepath = "%s/timeline/dynarex.xml" % @home    
      record = Dynarex.new(@home + '/dynarex.xml').find_by_title(@public_type)    
      thumbnail, subject_url = record.thumbnail, record.url
      
      content = {
              title: raw_msg, 
                url: static_url,
          thumbnail: thumbnail, 
        subject_url: subject_url, 
            raw_url: target_url 
      }

      publish_dynarex(timeline_filepath, content, rss: true)     

    end       
  end
end