<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();
const store = useStore();

const whatsappInboxes = useMapGetter('inboxes/getWhatsappInboxes');
const labels = useMapGetter('labels/getLabels');
const uiFlags = useMapGetter('campaigns/getUIFlags');
const isCreating = computed(() => uiFlags.value.isCreating);

const formState = ref({
  title: '',
  inbox: null,
  audience: [],
  scheduledAt: null,
  template: null,
  templateParams: {},
});

const templates = computed(() => {
  if (!formState.value.inbox) return [];

  // Use the proper getter from the store to get WhatsApp templates
  const rawTemplates = store.getters['inboxes/getWhatsAppTemplates'](
    formState.value.inbox
  );

  // Map templates to ComboBox format - template object as value, name as label
  const mappedTemplates = rawTemplates
    .filter(template => template && template.name)
    .map(template => ({
      value: template, // Store the entire template object
      label: template.name,
    }));

  return mappedTemplates;
});

watch(
  () => formState.value.inbox,
  () => {
    formState.value.template = null;
    formState.value.templateParams = {};
  }
);

const rules = {
  title: { required },
  inbox: { required },
  audience: { required },
  scheduledAt: { required },
  template: { required },
};

const v$ = useVuelidate(rules, formState);

const selectedTemplateParams = computed(() => {
  if (!formState.value.template) return [];

  // Get the template body from components
  const bodyComponent = formState.value.template.components?.find(
    component => component.type === 'BODY'
  );

  if (!bodyComponent?.text) return [];

  const message = bodyComponent.text;
  const regex = /\{\{([1-9])\}\}/g;
  let match;
  const params = new Set();
  // eslint-disable-next-line no-cond-assign
  while ((match = regex.exec(message)) !== null) {
    params.add(match[1]);
  }
  return Array.from(params).sort();
});

// 🆕 PREVIEW FUNCTIONALITY
const templateBody = computed(() => {
  if (!formState.value.template) return '';
  const bodyComponent = formState.value.template.components?.find(
    component => component.type === 'BODY'
  );
  return bodyComponent?.text || '';
});

const previewMessage = computed(() => {
  if (!templateBody.value) return '';
  return formatMessage(templateBody.value, formState.value.templateParams);
});

const missingParams = computed(() => {
  return selectedTemplateParams.value.filter(
    param => !formState.value.templateParams[param]?.trim()
  );
});

const hasValidPreview = computed(() => {
  return templateBody.value && missingParams.value.length === 0;
});

const missingParamsText = computed(() => {
  return missingParams.value.map(p => '{{' + p + '}}').join(', ');
});

const handleSubmit = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  // Get the template body from components
  const bodyComponent = formState.value.template.components?.find(
    component => component.type === 'BODY'
  );
  const templateBodyText = bodyComponent?.text || '';

  // eslint-disable-next-line no-console
  console.log('WhatsApp Campaign Submit:', {
    template: formState.value.template,
    templateParams: formState.value.templateParams,
    templateBody: templateBodyText,
  });

  const campaignData = {
    title: formState.value.title,
    inbox_id: formState.value.inbox,
    audience: formState.value.audience.map(id => ({
      id,
      type: 'Label',
    })),
    scheduled_at: new Date(formState.value.scheduledAt).toISOString(),
    campaign_type: 'one_off',
    template_info: {
      name: formState.value.template.name,
      language: formState.value.template.language,
      body: templateBodyText,
      processed_params: formState.value.templateParams,
    },
    message: formatMessage(templateBodyText, formState.value.templateParams),
  };
  emit('submit', campaignData);
};

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() => mapToOptions(labels.value, 'id', 'title'));

const inboxOptions = computed(() =>
  mapToOptions(whatsappInboxes.value, 'id', 'name')
);
</script>

<template>
  <form class="flex flex-col h-full" @submit.prevent="handleSubmit">
    <div
      class="flex-grow w-full px-8 pt-6 pb-4 space-y-4 overflow-y-auto"
      :class="{ 'is-invalid': v$.$invalid }"
    >
      <Input
        v-model="formState.title"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
        :has-error="v$.title.$error"
        :error-message="
          v$.title.$error ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.ERROR') : ''
        "
        @blur="v$.title.$touch"
      />
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
        </label>
        <ComboBox
          v-model="formState.inbox"
          :options="inboxOptions"
          :has-error="v$.inbox.$error"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
          :message="
            v$.inbox.$error
              ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.ERROR')
              : ''
          "
          @input="v$.inbox.$touch"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
        </label>
        <ComboBox
          v-model="formState.template"
          :options="templates"
          :has-error="v$.template.$error"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
          :message="
            v$.template.$error
              ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.ERROR')
              : ''
          "
          @input="v$.template.$touch"
        />
      </div>

      <div v-if="selectedTemplateParams.length > 0" class="mb-4">
        <h3 class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE_VARIABLES.TITLE') }}
        </h3>
        <p class="text-xs text-slate-600 dark:text-slate-300">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE_VARIABLES.SUBTITLE') }}
        </p>
        <div class="mt-2 space-y-2">
          <Input
            v-for="param in selectedTemplateParams"
            :key="param"
            v-model="formState.templateParams[param]"
            :label="`{{${param}}}`"
            class="w-full"
            :placeholder="
              t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PARAM_PLACEHOLDER', {
                param,
              })
            "
            :has-error="
              missingParams.includes(param) &&
              formState.templateParams[param] !== undefined
            "
          />
        </div>
      </div>

      <!-- 🆕 MESSAGE PREVIEW SECTION -->
      <div v-if="formState.template" class="mb-4">
        <h3 class="text-sm font-medium text-slate-800 dark:text-slate-100 mb-2">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.TITLE') }}
        </h3>

        <!-- Validation Warnings -->
        <div
          v-if="missingParams.length > 0"
          class="mb-3 p-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg"
        >
          <div class="flex items-center gap-2 mb-1">
            <svg
              class="w-4 h-4 text-amber-600 dark:text-amber-400"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fill-rule="evenodd"
                d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                clip-rule="evenodd"
              />
            </svg>
            <span
              class="text-sm font-medium text-amber-800 dark:text-amber-200"
            >
              {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.MISSING_PARAMS') }}
            </span>
          </div>
          <p class="text-xs text-amber-700 dark:text-amber-300">
            {{
              t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.MISSING_PARAMS_LIST', {
                params: missingParamsText,
              })
            }}
          </p>
        </div>

        <!-- WhatsApp-like Preview -->
        <div
          class="bg-gradient-to-b from-green-400 to-green-500 p-4 rounded-t-lg"
        >
          <div class="flex items-center text-white gap-2">
            <div
              class="w-8 h-8 bg-white/20 rounded-full flex items-center justify-center"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path
                  d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.487"
                />
              </svg>
            </div>
            <div>
              <p class="font-medium text-sm">
                {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.BUSINESS_NAME') }}
              </p>
              <p class="text-xs opacity-90">
                {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.ONLINE') }}
              </p>
            </div>
          </div>
        </div>

        <div
          class="bg-gray-100 dark:bg-gray-800 p-4 min-h-[120px] rounded-b-lg border-l-4 border-gray-300 dark:border-gray-600"
        >
          <div
            class="bg-white dark:bg-gray-700 rounded-lg p-3 shadow-sm max-w-xs ml-auto"
          >
            <div
              v-if="hasValidPreview"
              class="text-sm text-gray-800 dark:text-gray-200 whitespace-pre-wrap"
            >
              {{ previewMessage }}
            </div>
            <div v-else class="text-sm text-gray-500 dark:text-gray-400 italic">
              {{
                templateBody ||
                t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW.NO_TEMPLATE')
              }}
            </div>
            <div class="flex justify-end items-center mt-2 gap-1">
              <span class="text-xs text-gray-500 dark:text-gray-400">
                {{
                  new Date().toLocaleTimeString([], {
                    hour: '2-digit',
                    minute: '2-digit',
                  })
                }}
              </span>
              <svg
                v-if="hasValidPreview"
                class="w-4 h-4 text-blue-500"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
        </label>
        <TagMultiSelectComboBox
          v-model="formState.audience"
          :options="audienceList"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
          :has-error="v$.audience.$error"
          :message="
            v$.audience.$error
              ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.ERROR')
              : ''
          "
        />
      </div>

      <Input
        v-model="formState.scheduledAt"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
        type="datetime-local"
        :has-error="v$.scheduledAt.$error"
        :placeholder="
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')
        "
        :message="
          v$.scheduledAt.$error
            ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.ERROR')
            : ''
        "
        @blur="v$.scheduledAt.$touch"
      />
    </div>
    <div
      class="flex justify-end w-full gap-2 px-8 py-4 bg-slate-50 dark:bg-slate-800"
    >
      <Button
        variant="faded"
        color="slate"
        class="w-full bg-n-alpha-2 text-n-blue-text hover:bg-n-alpha-3"
        @click="$emit('cancel')"
      >
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL') }}
      </Button>
      <Button
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="v$.$invalid || missingParams.length > 0"
      >
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE') }}
      </Button>
    </div>
  </form>
</template>
