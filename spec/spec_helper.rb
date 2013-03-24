require 'blurrily'

RSpec.configure do |config|
  config.before(:each) do
  end

  config.after(:each) do
  end
end

Pathname.class_eval do
  def md5sum
    Digest::MD5.file(self.to_s)
  end
end
