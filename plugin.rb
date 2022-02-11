# frozen_string_literal: true

# name: discourse-x-multilingual-helper
# about: Discourse plugin that helps to create multilingual versions of categories, topics and posts
# version: 1.0
# authors: Anton Pishel
# contact email: apishel@gmail.com
# url: https://github.com/acestream/discourse-x-multilingual-helper

enabled_site_setting :multilingual_helper_enabled
register_asset 'stylesheets/common.scss'

# This module holds category translations loaded from config file
module Translations
  @@data = {}

  def self.setData(value)
    @@data = value
  end

  def self.data
    @@data
  end
end

# Load translations for category names from config file
def reload_translations
  begin
    path = SiteSetting.category_translations_path
    if File.exists?(path)
      file = File.open path
      data = JSON.load(file)
    else
      data = {}
    end
  rescue => error
    data = {}
    STDERR.puts "Failed to load translations: #{error}"
  end

  Translations.setData(data)
end

after_initialize do
  reload_translations()

  register_category_custom_field_type("description_excerpt_ru", :string)
  register_topic_custom_field_type("excerpt_ru", :string)
  register_topic_custom_field_type("title_ru", :string)
  register_post_custom_field_type("cooked_ru", :string)

  # Need to preload custom fields for listable topic
  add_preloaded_topic_list_custom_field("excerpt_ru")
  add_preloaded_topic_list_custom_field("title_ru")

  # Reload translations when config path changed
  on(:site_setting_changed) do |setting, old_val, new_val|
    if setting.to_sym == :category_translations_path
      reload_translations()
    end
  end

  # Add "name_translations" field that is used by discourse-multilingual plugin
  # to show translated categories names.
  add_to_serializer(:basic_category, :name_translations) do
    Translations.data[object.slug]
  end

  # Replace category.excerpt with category.excerpt_ru when appropriate
  add_to_serializer(:basic_category, :description_excerpt) do
    if I18n.locale == :ru and object.custom_fields["description_excerpt_ru"]
      PrettyText.excerpt(object.custom_fields["description_excerpt_ru"], 300)
    else
      object.uncategorized? ? I18n.t('category.uncategorized_description', locale: I18n.locale) : object.description_excerpt
    end
  end

  # Replace topic.excerpt with topic.excerpt_ru when appropriate
  add_to_serializer(:listable_topic, :excerpt) do
    if I18n.locale == :ru and object.custom_fields["excerpt_ru"]
      object.custom_fields["excerpt_ru"]
    else
      object.excerpt
    end
  end

  add_to_serializer(:listable_topic, :title_ru) do
    object.custom_fields["title_ru"]
  end

  add_to_serializer(:topic_view, :title_ru) do
    object.topic.custom_fields["title_ru"]
  end

  # Replace post.cooked with post.cooked_ru when appropriate.
  # Most of the code is copied from the original "cooked" method.
  add_to_serializer(:basic_post, :cooked) do
    if cooked_hidden
      if scope.current_user && object.user_id == scope.current_user.id
        I18n.t('flagging.you_must_edit', path: "/my/messages")
      else
        I18n.t('flagging.user_must_edit')
      end
    else
      if @parent_post.blank?
        if I18n.locale == :ru and object.custom_fields["cooked_ru"]
          object.custom_fields["cooked_ru"]
        else
          object.cooked
        end
      else
        object.filter_quotes(@parent_post)
      end
    end
  end

  # Parse original "cooked" post text and split it into translated parts.
  # Current format: two parst (EN and RU) delimited with "===ru===" string.
  Plugin::Filter.register(:after_post_cook) do |post, cooked|
    if post.is_first_post?
      # 0 = EN
      # 1 = RU
      parsed = cooked.split("===ru===")

      # Special handling only when the delimiter is present
      if parsed.length() == 2
        # replace original "cooked" with EN version
        cooked = parsed[0]
        cooked_ru = parsed[1]
        post.custom_fields["cooked_ru"] = cooked_ru

        post.topic.category.description = cooked_en
        post.topic.category.custom_fields["description_excerpt_ru"] = cooked_ru
        post.topic.category.save!

        topic_excerpt_ru = Post.excerpt(parsed[1], SiteSetting.topic_excerpt_maxlength, strip_links: true, strip_images: true, post: post)
        post.topic.custom_fields["excerpt_ru"] = topic_excerpt_ru
        post.topic.save!
      end
    end
    cooked
  end

  on(:topic_created) do |topic, opts, user|
    topic.custom_fields["title_ru"] = opts[:title_ru]
    topic.save!
  end
  
  PostRevisor.track_topic_field(:title_ru) do |tc, value|
    tc.record_change("title_ru", tc.topic.custom_fields["title_ru"], value)
    tc.topic.custom_fields["title_ru"] = value.present? ? value : nil
  end

end