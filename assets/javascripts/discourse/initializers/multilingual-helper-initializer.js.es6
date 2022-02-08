import I18n from "I18n";
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "multilingual-helper-intializer",
  initialize(container) {
    const fieldName = 'title_ru';
    const fieldType = 'string';
    
    withPluginApi('0.11.2', api => {
      
      // Show custom field "title_ru" when editing topic to admins.
      const user = api.getCurrentUser();
      if(user && user.admin) {
        api.registerConnectorClass('edit-topic', 'edit-topic-custom-field-container', {
          setupComponent(attrs, component) {
            const model = attrs.model;

            let props = {
              fieldName: fieldName,
              fieldValue: model.get(fieldName)
            }
            component.setProperties(props);
          },

          actions: {
            onChangeField(fieldValue) {
              this.set(`buffered.${fieldName}`, fieldValue);
            }
          }
        });
      }

      // Change topic title to RU locale if available
      api.decorateTopicTitle((model, title) => {
        if(I18n.locale === 'ru' && model.title_ru) {
          title.innerHTML = model.title_ru;
        }
      });
    });
  }
}