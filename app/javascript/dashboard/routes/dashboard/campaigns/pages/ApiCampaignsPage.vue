<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import ApiCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ApiCampaign/ApiCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import SMSCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/SMSCampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showApiCampaignDialog, toggleApiCampaignDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);

const apiCampaigns = computed(() => {
  const allOneOffCampaigns = getters['campaigns/getCampaigns'].value(
    CAMPAIGN_TYPES.ONE_OFF
  );

  return allOneOffCampaigns.filter(campaign => {
    return campaign.inbox && campaign.inbox.channel_type === 'Channel::Api';
  });
});

const hasNoApiCampaigns = computed(
  () => apiCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.API.HEADER')"
    :button-label="t('CAMPAIGN.API.NEW_BUTTON')"
    @click="toggleApiCampaignDialog()"
    @close="toggleApiCampaignDialog(false)"
  >
    <template #action>
      <ApiCampaignDialog
        v-if="showApiCampaignDialog"
        @close="toggleApiCampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoApiCampaigns"
      :campaigns="apiCampaigns"
      @delete="handleDelete"
    />
    <SMSCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.API.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.API.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
