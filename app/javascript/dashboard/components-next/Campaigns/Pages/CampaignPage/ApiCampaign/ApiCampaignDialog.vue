<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useVuelidate } from '@vuelidate/core';
import { required, requiredIf } from '@vuelidate/validators';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['close']);
const { t } = useI18n();
const store = useStore();

// Form data
const formData = reactive({
  title: '',
  message: '',
  inbox_id: null,
  scheduled_at: null,
  audience: [],
  enabled: true,
  sender_id: null,
});

// Validation rules
const rules = {
  title: { required },
  message: { required },
  inbox_id: { required },
  audience: {
    required: requiredIf(() => true),
  },
  scheduled_at: { required },
};

const $v = useVuelidate(rules, formData);

// Store getters
const inboxes = computed(() =>
  store.getters['inboxes/getInboxes'].filter(
    inbox => inbox.channel_type === 'Channel::Api'
  )
);

const agents = computed(() => store.getters['agents/getAgents']);

const uiFlags = computed(() => store.getters['campaigns/getUIFlags']);

// Inbox options for dropdown
const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

// Agent options for dropdown
const agentOptions = computed(() => [
  { value: null, label: t('CAMPAIGN.API.AGENT_OPTIONS.SYSTEM') },
  ...agents.value.map(agent => ({
    value: agent.id,
    label: agent.name,
  })),
]);

// Map labels for audience selection
const audienceList = computed(() =>
  store.getters['labels/getLabels'].map(label => ({
    value: label.id,
    label: label.title,
  }))
);

// No need for watch since we're using v-if in the parent

// Reset form
const resetForm = () => {
  Object.assign(formData, {
    title: '',
    message: '',
    inbox_id: null,
    scheduled_at: null,
    audience: [],
    enabled: true,
    sender_id: null,
  });
  $v.value.$reset();
};

// Handle dialog close
const handleClose = () => {
  resetForm();
  emit('close');
};

// Handle form submission
const handleSubmit = async () => {
  $v.value.$touch();

  if ($v.value.$invalid) {
    return;
  }

  try {
    const campaignData = {
      title: formData.title,
      message: formData.message,
      inbox_id: formData.inbox_id,
      sender_id: formData.sender_id,
      scheduled_at: new Date(formData.scheduled_at).toISOString(),
      enabled: formData.enabled,
      audience: formData.audience.map(id => ({
        id,
        type: 'Label',
      })),
      campaign_type: 'one_off',
    };

    await store.dispatch('campaigns/create', campaignData);

    resetForm();
    emit('close');
  } catch (error) {
    // Error creating API campaign
    // Handle error appropriately in a real application
  }
};

// Current date time for minimum scheduled time
const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});
</script>

<template>
  <div
    class="w-[25rem] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] p-6 rounded-xl border border-n-weak shadow-md flex flex-col gap-6 max-h-[85vh] overflow-y-auto"
  >
    <h3 class="text-base font-medium text-n-slate-12">
      {{ t('CAMPAIGN.API.DIALOG.TITLE') }}
    </h3>
    <form @submit.prevent="handleSubmit">
      <div class="space-y-6">
        <!-- Basic Information -->
        <div class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CAMPAIGN.API.FORM.BASIC_INFO.TITLE') }}
          </h3>

          <Input
            v-model="formData.title"
            :label="t('CAMPAIGN.API.FORM.TITLE.LABEL')"
            :placeholder="t('CAMPAIGN.API.FORM.TITLE.PLACEHOLDER')"
            :has-error="$v.title.$error"
            :message="$v.title.$error ? t('CAMPAIGN.API.FORM.TITLE.ERROR') : ''"
          />

          <div class="flex flex-col gap-1">
            <label class="mb-0.5 text-sm font-medium text-n-slate-12">
              {{ t('CAMPAIGN.API.FORM.INBOX.LABEL') }}
            </label>
            <ComboBox
              v-model="formData.inbox_id"
              :options="inboxOptions"
              :placeholder="t('CAMPAIGN.API.FORM.INBOX.PLACEHOLDER')"
              :has-error="$v.inbox_id.$error"
              :message="
                $v.inbox_id.$error ? t('CAMPAIGN.API.FORM.INBOX.ERROR') : ''
              "
              class="[&>div>button]:bg-n-alpha-black2"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="mb-0.5 text-sm font-medium text-n-slate-12">
              {{ t('CAMPAIGN.API.FORM.SENDER.LABEL') }}
            </label>
            <ComboBox
              v-model="formData.sender_id"
              :options="agentOptions"
              :placeholder="t('CAMPAIGN.API.FORM.SENDER.PLACEHOLDER')"
              class="[&>div>button]:bg-n-alpha-black2"
            />
          </div>
        </div>

        <!-- Message Section -->
        <div class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CAMPAIGN.API.FORM.MESSAGE.TITLE') }}
          </h3>

          <TextArea
            v-model="formData.message"
            :label="t('CAMPAIGN.API.FORM.MESSAGE.LABEL')"
            :placeholder="t('CAMPAIGN.API.FORM.MESSAGE.PLACEHOLDER')"
            :has-error="$v.message.$error"
            :message="
              $v.message.$error ? t('CAMPAIGN.API.FORM.MESSAGE.ERROR') : ''
            "
            rows="4"
          />

          <!-- Message Preview -->
          <div class="border rounded-lg p-4 bg-n-alpha-black2">
            <h4 class="text-sm font-medium text-n-slate-11 mb-3">
              {{ t('CAMPAIGN.API.FORM.MESSAGE.PREVIEW') }}
            </h4>
            <div class="text-sm text-n-slate-12 p-3 bg-n-alpha-black3 rounded">
              {{
                formData.message || t('CAMPAIGN.API.FORM.MESSAGE.PLACEHOLDER')
              }}
            </div>
          </div>
        </div>

        <!-- Audience Section -->
        <div class="flex flex-col gap-1">
          <label class="mb-0.5 text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.API.FORM.AUDIENCE.LABEL') }}
          </label>
          <TagMultiSelectComboBox
            v-model="formData.audience"
            :options="audienceList"
            :placeholder="t('CAMPAIGN.API.FORM.AUDIENCE.PLACEHOLDER')"
            :has-error="$v.audience.$error"
            :message="
              $v.audience.$error ? t('CAMPAIGN.API.FORM.AUDIENCE.ERROR') : ''
            "
          />
        </div>

        <!-- Timing Section -->
        <div class="flex flex-col gap-1">
          <Input
            v-model="formData.scheduled_at"
            :label="t('CAMPAIGN.API.FORM.TIMING.LABEL')"
            type="datetime-local"
            :min="currentDateTime"
            :has-error="$v.scheduled_at.$error"
            :message="
              $v.scheduled_at.$error ? t('CAMPAIGN.API.FORM.TIMING.ERROR') : ''
            "
          />
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-end w-full gap-2 mt-6">
        <Button
          variant="faded"
          color="slate"
          class="w-full bg-n-alpha-2 text-n-blue-text hover:bg-n-alpha-3"
          @click="handleClose"
        >
          {{ t('CAMPAIGN.API.FORM.ACTIONS.CANCEL') }}
        </Button>

        <Button
          type="submit"
          class="w-full"
          :is-loading="uiFlags.isCreating"
          :disabled="$v.$invalid"
        >
          {{ t('CAMPAIGN.API.FORM.ACTIONS.CREATE') }}
        </Button>
      </div>
    </form>
  </div>
</template>
