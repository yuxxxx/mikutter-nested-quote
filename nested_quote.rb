# -*- coding: utf-8 -*-

class Gdk::NestedQuote < Gdk::SubParts
  regist

  TWEET_URL = [ /^https?:\/\/twitter.com\/(?:#!\/)?[a-zA-Z0-9_]+\/status(?:es)?\/(\d+)(?:\?.*)?$/,
                /^http:\/\/favstar\.fm\/users\/[a-zA-Z0-9_]+\/status\/(\d+)/ ]
  attr_reader :icon_width, :icon_height
  
  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @edge = 32, 32, 2, 8
    @message_got = false
    @messages = []
    if not get_tweet_ids.empty?
      get_tweet_ids.each_with_index{ |message_id, render_idnex|
        Thread.new {
          m = Message.findbyid(message_id.to_i)
          if m.is_a? Message
            Delayer.new{
              m[:render_index] = render_idnex
              render_message(m) } end } } end
      if message and not helper.visible?
        sid = helper.ssc(:expose_event, helper){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false } end
  end

  def render_message(message)
    notice "found #{message.to_s}"
    if not helper.destroyed?
      @message_got = true
      @messages << message
      @messages = @messages.sort_by{ |m| m[:render_index] }
      helper.on_modify
      helper.reset_height end
  end

  def render(context)
    if helper.visible? and messages
      offset = 0
      messages.length.times{ |i|
        render_outline(i, context, offset)
        header(i, context, offset)
        context.save {
          context.translate(@margin+@edge, @margin+@edge + offset)
          render_main_icon(i, context)
          context.translate(@icon_width + @margin*2, header_left(i).size[1]/Pango::SCALE)
          context.set_source_rgb(*([0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(main_message(i, context)) }
        offset += get_message_height(i)
      }
    end
  end

  def height
    if not(helper.destroyed?) and has_tweet_url? and messages and not messages.empty?
      h = 0
      messages.length.times.map { |i|
        get_message_height(i)
      }
      h
    else
      0 end end

  private
  def get_message_height(i)
      [icon_height, (header_left(i).size[1]+main_message(i).size[1])/Pango::SCALE].max + (@margin+@edge)*2
  end

  def id2url(url)
    TWEET_URL.each{ |regexp|
      m = regexp.match(url)
      return m[1] if m }
    false end

  # ツイートへのリンクを含んでいれば真
  def has_tweet_url?
    message.entity.any?{ |entity|
      :urls == entity[:slug] and id2url(entity[:expanded_url]) } end

  # ツイートの本文に含まれるツイートのパーマリンクを返す
  # ==== Return
  # URLの配列
  def get_tweet_ids
    message.entity.map{ |entity|
      if :urls == entity[:slug]
        id2url(entity[:expanded_url]) end }.select(&ret_nth) end

  def messages
    @messages if @message_got end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(i,context = dummy_context)
    message = messages[i]
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(i,context = dummy_context)
    message = messages[i]
    now = Time.now
    hms = if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
            message[:created].strftime('%H:%M:%S')
          else
            message[:created].strftime('%Y/%m/%d %H:%M:%S')
          end
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(hms)}</span>")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  def header(i,context, offset)
    header_w = width - @icon_width - @margin*3 - @edge*2
    context.save{
      context.translate(@icon_width + @margin*2 + @edge, @margin + @edge + offset)
      context.set_source_rgb(0,0,0)
      hl_layout, hr_layout = header_left(i, context), header_right(i, context)
      context.show_pango_layout(hl_layout)
      context.save{
        context.translate(header_w - hr_layout.size[0] / Pango::SCALE, 0)
        if (hl_layout.size[0] / Pango::SCALE) > header_w - hr_layout.size[0] / Pango::SCALE - 20
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, 0)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE)
          context.set_source(grad)
          context.fill() end
        context.show_pango_layout(hr_layout) } }
  end

  def escaped_main_text(i)
    Pango.escape(messages[i].to_show) end

  def main_message(i,context = dummy_context)
    attr_list, text = Pango.parse_markup(escaped_main_text(i))
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3 - @edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_main_icon(i,context)
    context.set_source_pixbuf(main_icon(i))
    context.paint
  end

  def render_outline(i,context, yoffset)
    context.save {
      context.translate(0, yoffset)
      context.pseudo_blur(4) {
        context.fill {
          context.set_source_rgb(*([32767, 32767, 32767]).map{ |c| c.to_f / 65536 })
          context.rounded_rectangle(@edge, @edge, width-@edge*2, get_message_height(i)-@edge*2, 4)
        }
      }
      context.fill {
        context.set_source_rgb(*([65535, 65535, 65535]).map{ |c| c.to_f / 65536 })
        context.rounded_rectangle(@edge, @edge, width-@edge*2, get_message_height(i)-@edge*2, 4)
      }
    }
  end

  def main_icon(i)
    @main_icon = Gdk::WebImageLoader.pixbuf(messages[i][:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      @main_icon = pixbuf
      helper.on_modify } end

  def message
    helper.message end

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, helper.color).create_cairo_context end

  def get_backgroundcolor
    [1.0, 1.0, 1.0]
  end
  
end

Plugin.create :nested_quote do
  command(:copy_tweet_url,
          :name => 'ツイートのURLをコピー',
          :condition => Proc.new{|opt| !opt.messages.any?(&:system?)},
          :visible => true,
          :role => :timeline) do |opt|
    message = opt.messages.first.message
    Gtk::Clipboard.copy("https://twitter.com/#{message.idname}/statuses/#{message.id}")
       end
end
