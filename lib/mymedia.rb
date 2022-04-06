#!/usr/bin/env ruby

# file: mymedia.rb

require 'time'
require 'logger'
require 'dynarex'
require 'sps-pub'
require 'dir-to-xml'
require 'dataisland'
require 'increment'
require 'simple-config'
require 'rxfileio'
require 'wordsdotdat'


module MyMedia

  class MyMediaPublisherException < Exception
  end


  class Publisher
    include RXFReadWriteModule

    def initialize(opts={})
      @index_page = true
      @opts = opts
    end

    protected

    def publish_dynarex(dynarex_filepath='', \
          record={title: '',url: '', raw_url: ''}, options={})

      opt = {id: nil, rss: false}.merge(options)

      dynarex = if FileX.exists? dynarex_filepath then
        Dynarex.new(dynarex_filepath)
      else
        Dynarex.new(@schema)
      end

      dynarex.create record, id: opt[:id]
      dynarex.save dynarex_filepath
      publish_html(dynarex_filepath)  if @index_page == true


      if opt[:rss] == true then

        dynarex.xslt_schema = dynarex.summary[:xslt_schema]
        rss_filepath = dynarex_filepath.sub(/\.xml$/,'_rss.xml')
        FileX.write rss_filepath, dynarex.to_rss
      end

    end

    def publish_html(filepath)

      path2 = File.dirname(filepath)
      template_path = File.join path2, 'index-template.html'

      return unless @index_page == true
      raise MyMediaPublisherException, \
          "template path: #{template_path} not found" unless \
                                                    FileX.exists?(template_path)
=begin jr 040916
      dataisland = DataIsland.new(template_path, @opts)

      File.open(path2 + '/index.html','w'){|f| f.write dataisland.html_doc.xml pretty: true}
=end
    end

    def publish_dxlite(dynarex_filepath='', record={title: '',url: ''})

      dynarex = if FileX.exists? dynarex_filepath then
        DxLite.new(dynarex_filepath)
      else
        DxLite.new(@schema, order: 'descending')
      end

      dynarex.create record
      dynarex.save dynarex_filepath
    end

    def send_message(topic: @sps[:default_subscriber], msg: '')

      fqm = "%s: %s" % [topic, msg]

      SPSPub.notice fqm, address: @sps[:address]
      sleep 0.3
    end

  end

  module IndexReader
    include RXFRead

    def browse(startswith=nil)

      json_filepath = "%s/%s/dynarex.json" % [@home, @public_type]

      if FileX.exists? json_filepath then

        dx = DxLite.new(json_filepath)

        if startswith then

          @stopwords = WordsDotDat.stopwords
          q = startswith

          r = dx.all.select do |x|

            found = x.title.scan(/\b\w+/).select do |raw_word|

              word = raw_word.downcase
              word[0..(q.length-1)] == q and not @stopwords.include? word

            end

            found.any?
          end

        else

          return dx.all

        end

      end

    end

    def search(keyword)

      json_filepath = "%s/%s/dynarex.json" % [@home, @public_type]

      if FileX.exists? json_filepath then

        dx = DxLite.new(json_filepath)
        return dx.all.select {|x| x.title =~ /#{keyword}/i}

      end

    end
  end

  class BaseException < Exception
  end

  class Base < Publisher
    include RXFileIOModule

    attr_reader :to_s

    def initialize(media_type: 'blog', public_type: media_type,
                   ext: 'txt', config: nil, log: nil, debug: false)

      super()

      @schema = 'posts/post(title, url, raw_url)'

      raise BaseException, "no config found" if config.nil?

      c = SimpleConfig.new(config).to_h

      @home = c[:home]
      puts '@home: ' + @home.inspect if @debug
      @media_src = "%s/media/%s" % [@home, media_type]
      @website = c[:website]

      @dynamic_website = c[:dynamic_website]
      @www = c[:www]
      @domain = @website[/[^\.]+\.[^\.]+$/]

      @sps = c[:sps]
      @omit_html_ext = c[:omit_html_ext]

      @log = log


      @media_type = media_type
      @public_type = public_type ||= @media_type

      @xslt_schema = 'channel[title:title,description:desc]/' + \
                                                'item(title:title,link:url)'
      @ext = ext
      @rss = false
      @debug = debug

      DirX.chdir @home

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

    def auto_copy_publish(raw_msg='', &blk)

      @log.info 'Base inside auto_copy_publish' if @log
      puts '@media_src: ' + @media_src.inspect if @debug

      # fetch the most recent file
      filename = FileX.ru_r @media_src

      if filename then

        puts 'filename: ' + filename.inspect if @debug

        copy_publish( filename ,raw_msg, &blk)

      end

    end

    def basename(raw_s1, raw_s2)

      s1 = raw_s1.sub(/dfs:\/\/[^\/]+/,'')
      s2 = raw_s2.sub(/dfs:\/\/[^\/]+/,'')

      (s2.split('/') - s1.split('/')).join('/')

    end

    def copy_publish(filename, raw_msg='', &blk)
      file_publish(filename, raw_msg)
    end


    private

    def file_publish(src_path, raw_msg='')

      #raise @logger.debug("source file '%s' not found" % src_path) unless File.exists? src_path
      ext = File.extname(src_path)
      @target_ext ||= ext

      public_path = "%s/%s/%shrs%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, Time.now.strftime('%H%M'),
                                      @target_ext]

      public_path2 = "%s/%s/%shrs%s%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, Time.now.strftime('%H%M'),
                                       Time.now.strftime('%S%2N'), @target_ext]

      raw_destination = "%s/%s/%s" % [@home, 'r', public_path]

      if FileX.exists? raw_destination then
        raw_destination = "%s/%s/%s" % [@home, 'r', public_path2]
        public_path = public_path2
      end

      destination = File.join(@home, public_path)
      FileX.mkdir_p File.dirname(raw_destination)
      FileX.mkdir_p File.dirname(destination)

      if @debug then
        puts "file_publish() #50 mkdir_p %s" % [File.dirname(raw_destination)]
        puts "file_publish() #70 mkdir_p %s" % [File.dirname(destination)]
      end

      raw_msg = raw_msg.join ' ' if raw_msg.is_a? Array

      raw_msg = src_path[/([^\/]+)\.\w+$/,1] + ' ' + raw_msg if raw_msg[/^#/]


      if block_given? then
        raw_msg, target_url = yield(destination, raw_destination)
        static_url = target_url
      else

        if @debug then
          puts "file_publish() #80 cp %s to %s" % [src_path, destination]
          puts "file_publish() #90 cp %s to %s" % [src_path, destination]
        end

        FileX.cp src_path, destination
        FileX.cp src_path, raw_destination

        if @debug then
          puts "file_publish() #100 copied %s to %s" % [src_path, destination]
          puts "file_publish() #200 copied %s to %s" % \
              [src_path, raw_destination]
        end

      end

      raw_msg = raw_msg.join if raw_msg.is_a? Array

      static_filename = if raw_msg.to_s.length > 0 then
         normalize(raw_msg) + File.extname(destination)
      else

        basename(@media_src, src_path)

      end

      static_path = "%s/%s/%s" % [@public_type, \
        Time.now.strftime('%Y/%b/%d').downcase, static_filename]

      raw_static_destination = "%s/%s/%s" % [@home, 'r',static_path]

      static_destination = "%s/%s" % [@home, static_path]

      #FileUtils.mkdir_p File.dirname(static_destination)

      if @debug then
        puts "file_publish() #300 copy %s to %s" % [destination,
                                                      static_destination]
      end

      FileX.cp destination, static_destination

      #jr010817 FileUtils.cp raw_destination, raw_static_destination

      # Make a static filename XML file copy?
      if File.extname(static_destination) == '.html' then

        xmlfilepath = destination.sub('.html','.xml')

        if FileX.exists?(xmlfilepath) then

          FileX.cp xmlfilepath, static_destination.sub('.html','.xml')

          if @debug then
            puts "file_publish() #400 copied %s to %s" % [xmlfilepath, static_destination.sub('.html','.xml')]
          end

        end

      end

      target_url ||= "%s/%s" % [@website, public_path]
      static_url ||= "%s/%s" % [@website, static_path]

      msg = "%s %s" % [target_url, raw_msg ]

      sps_message = ['publish', @public_type,
                    target_url, static_url, raw_msg]

      send_message(msg: sps_message.join(' '))

      static_url

    end

    def normalize(s)

      r = s.downcase.gsub(/\s#\w+/,'').strip.gsub(/\W/,'-').gsub(/-{2,}/,'-').gsub(/^-|-$/,'')
      return s.scan(/#(\w+)/)[0..1].join('_').downcase if r.empty?
      return r
    end

  end


  class FrontpageException < Exception
  end

  class Frontpage < Publisher

    def initialize(config: nil, public_type: '', rss: nil)

      raise FrontpageException, "no config found" if config.nil?

      c = SimpleConfig.new(config).to_h

      @home = c[:home]
      @index_page = c[:index_page] == 'true'
      @public_type = public_type
      @rss = rss
      @sps = c[:sps]
      @opts = {username: c[:username], password: c[:password]}

    end

    def publish_frontpage(s='index.html')

      publish_html(@home + '/' + s)
      'frontpage published'
    end


    def publish_to_lists(record={}, public_type=nil)

      @log.info 'inside publish_to_lists' if @log

      @public_type = public_type if public_type

      raw_msg, static_url, target_url = \
          record[:title], record[:url], record[:static_url]

      dynarex_filepath = "%s/%s/dynarex.xml" % [@home, @public_type]
      raw_dynarex_filepath = "%s/r/%s/dynarex.xml" % [@home, @public_type]


      publish_dynarex(dynarex_filepath, record, {rss: @rss || false})
      publish_dynarex(raw_dynarex_filepath, record, {rss: @rss || false})

      publish_timeline(raw_msg, static_url, target_url)
      send_message(msg: 'publish_to_lists completed')

    end


    def publish_timeline(raw_msg, static_url, target_url='')

      timeline_filepath = "%s/timeline/dynarex.xml" % @home
      record = Dynarex.new(@home + '/dynarex/main-directory.xml').find_by_title(@public_type)

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
