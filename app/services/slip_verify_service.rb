class SlipVerifyService
  def self.get_token
    url = URI("https://vrich-slip-uat.vrich619.com:64321/api/reset-token")

    url = URI("https://vrich-slip.vrich619.com:64321/api/reset-token")

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["app_id"] = "207219"

    response = https.request(request)
    token = JSON.parse(response.body)['id_token']
    third_party = ThirdParty.find_by(name: 'vertify_slip')
    if third_party
      expiration_time = Time.now + 24.hours
      third_party.update(token: token, token_expire: expiration_time)
    else
      puts "Record ThirdParty verify_slip not found"
    end
    token
  end

  def self.verify_slip(sending_book, transaction_code)
    Rails.logger.info "Sending book: #{sending_book}, Transaction code: #{transaction_code}"
    # verify_slip = ThirdParty.find_by(name: "vertify_slip")
    # token = verify_slip.token
    # if verify_slip.token_expire < 10.minutes.from_now
    #   token = get_token
    # end
    # url = URI("https://vrich-slip-uat.vrich619.com:64321/api/skybox")

    # url = URI("https://vrich-slip.vrich619.com:64321/api/skybox")

    # https = Net::HTTP.new(url.host, url.port)
    # https.use_ssl = true
    # https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # request = Net::HTTP::Post.new(url)
    # request["Content-Type"] = "application/json"
    # request["Authorization"] = "Bearer #{token}"
    # request.body = JSON.dump({
    #   "sendingBank": sending_book,
    #   "transactionCode": transaction_code,
    # })

    # response = JSON.parse(https.request(request).body)
  end
end
