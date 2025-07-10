<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getWhatsAppTemplates } from 'dashboard/helper/whatsapp';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

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

const templates = ref([]);

watch(
  () => formState.value.inbox,
  async newInbox => {
    if (newInbox) {
      templates.value = await getWhatsAppTemplates(newInbox);
    } else {
      templates.value = [];
    }
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
  const message = formState.value.template.body;
  const regex = /\{\{([1-9])\}\}/g;
  let match;
  const params = new Set();
  // eslint-disable-next-line no-cond-assign
  while ((match = regex.exec(message)) !== null) {
    params.add(match[1]);
  }
  return Array.from(params).sort();
});

const handleSubmit = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

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
      body: formState.value.template.body,
      params: formState.value.templateParams,
    },
    message: formatMessage(
      formState.value.template.body,
      formState.value.templateParams
    ),
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
          label-key="name"
          value-key="name"
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
          />
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
        :disabled="v$.$invalid"
      >
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE') }}
      </Button>
    </div>
  </form>
</template>
