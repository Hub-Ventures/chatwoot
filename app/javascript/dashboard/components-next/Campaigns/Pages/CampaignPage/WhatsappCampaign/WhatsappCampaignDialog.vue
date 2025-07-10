<script setup>
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import WhatsappCampaignForm from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsappCampaign/WhatsappCampaignForm.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const handleSubmit = async campaign => {
  try {
    await store.dispatch('campaigns/create', campaign);
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE'));
  } finally {
    emit('close');
  }
};

const handleClose = () => {
  emit('close');
};
</script>

<template>
  <woot-modal show @close="handleClose">
    <woot-modal-header :header-title="t('CAMPAIGN.WHATSAPP.CREATE.TITLE')" />
    <WhatsappCampaignForm @submit="handleSubmit" @cancel="handleClose" />
  </woot-modal>
</template>
