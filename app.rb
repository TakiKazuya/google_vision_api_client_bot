require 'line/bot'
require "tempfile"
require "sinatra"
require 'google-cloud-vision'

get '/' do
  'hello world!'
end

post "/callback" do
  body = request.body.read
  signature = request.env["HTTP_X_LINE_SIGNATURE"]

  # unless client.validate_signature(body, signature)
  #   puts 'signature_error'
  #   error 400 do
  #     "Bad Request"
  #   end
  # end

  events = client.parse_events_from(body)
  events. each do |e|
    next unless e == Line::Bot::Event::Message ||  e.type == Line::Bot::Event::MessageType::Image

    response = @client.get_message_content(e.message['id'])
    case response
    when Net::HTTPSuccess
      tempfile = Tempfile.new(["tempfile", '.jpg']).tap do |file|
        file.write(response.body)
      end

      texts = image_to_texts(tempfile.path)
      client.reply_message(e['replyToken'], {
        type: 'text',
        text: texts.join
      })
    else
      puts response.code
      puts response.body
    end
  end

  "OK"
end


def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_id = ENV["LINE_CHANNEL_ID"]
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def image_to_texts(image_path)
  image_annotator = Google::Cloud::Vision.image_annotator

  response = image_annotator.text_detection(
    image: image_path,
    max_results: 1 # optional, defaults to 10
  )

  result = []
  response.responses.each do |res|
    res.text_annotations.each do |text|
      result << text.description
    end
  end

  result
end
