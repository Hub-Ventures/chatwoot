<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['import']);
const { t } = useI18n();

const uiFlags = useMapGetter('contacts/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');
const isImportingContact = computed(() => uiFlags.value.isImporting);

const dialogRef = ref(null);
const fileInput = ref(null);

const hasSelectedFile = ref(null);
const selectedFileName = ref('');
const selectedChannelIds = ref([]);
const associateToChannels = ref(false);

// Filtrar canales compatibles (API, Email, WhatsApp, SMS, etc.)
const availableChannels = computed(() => {
  const compatibleTypes = [
    'Channel::Api',
    'Channel::Email',
    'Channel::Whatsapp',
    'Channel::Sms',
    'Channel::TwilioSms',
  ];

  return inboxes.value.filter(inbox =>
    compatibleTypes.includes(inbox.channel_type)
  );
});

const csvUrl = '/downloads/import-contacts-sample.csv';

const handleFileClick = () => fileInput.value?.click();

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);

  return baseName.length > 20
    ? `${baseName.slice(0, 20)}...${extension}`
    : fileName;
};

const handleFileChange = () => {
  const file = fileInput.value?.files[0];
  hasSelectedFile.value = file;
  selectedFileName.value = file ? processFileName(file.name) : '';
};

const handleRemoveFile = () => {
  hasSelectedFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  selectedFileName.value = '';
};

const handleChannelToggle = channelId => {
  const index = selectedChannelIds.value.indexOf(channelId);
  if (index === -1) {
    selectedChannelIds.value.push(channelId);
  } else {
    selectedChannelIds.value.splice(index, 1);
  }
};

const selectAllChannels = () => {
  selectedChannelIds.value = availableChannels.value.map(channel => channel.id);
};

const clearAllChannels = () => {
  selectedChannelIds.value = [];
};

const handleAssociateToggle = () => {
  associateToChannels.value = !associateToChannels.value;
  if (!associateToChannels.value) {
    selectedChannelIds.value = [];
  }
};

const getChannelDisplayName = channel => {
  const typeMap = {
    'Channel::Api': 'API',
    'Channel::Email': 'Email',
    'Channel::Whatsapp': 'WhatsApp',
    'Channel::Sms': 'SMS',
    'Channel::TwilioSms': 'Twilio SMS',
  };

  const typeName = typeMap[channel.channel_type] || channel.channel_type;
  return `${channel.name} (${typeName})`;
};

const uploadFile = async () => {
  if (!hasSelectedFile.value) return;

  const channelIds = associateToChannels.value ? selectedChannelIds.value : [];
  emit('import', { file: hasSelectedFile.value, channelIds });
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TITLE')"
    :confirm-button-label="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT')
    "
    :is-loading="isImportingContact"
    :disable-confirm-button="isImportingContact || !hasSelectedFile"
    @confirm="uploadFile"
  >
    <template #description>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DESCRIPTION') }}
        <a
          :href="csvUrl"
          target="_blank"
          rel="noopener noreferrer"
          download="import-contacts-sample.csv"
          class="text-n-blue-text"
        >
          {{
            t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DOWNLOAD_LABEL')
          }}
        </a>
      </p>
    </template>

    <div class="flex flex-col gap-4">
      <!-- File Selection -->
      <div class="flex items-center gap-2">
        <label class="text-sm text-n-slate-12 whitespace-nowrap">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.LABEL') }}
        </label>
        <div class="flex items-center justify-between w-full gap-2">
          <span v-if="hasSelectedFile" class="text-sm text-n-slate-12">
            {{ selectedFileName }}
          </span>
          <Button
            v-if="!hasSelectedFile"
            :label="
              t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHOOSE_FILE')
            "
            icon="i-lucide-upload"
            color="slate"
            variant="ghost"
            size="sm"
            class="!w-fit"
            @click="handleFileClick"
          />
          <div v-else class="flex items-center gap-1">
            <Button
              :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANGE')"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleFileClick"
            />
            <div class="w-px h-3 bg-n-strong" />
            <Button
              icon="i-lucide-trash"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleRemoveFile"
            />
          </div>
        </div>
      </div>

      <!-- Channel Association -->
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <input
            id="associate-channels"
            v-model="associateToChannels"
            type="checkbox"
            class="w-4 h-4"
            @change="handleAssociateToggle"
          />
          <label
            for="associate-channels"
            class="text-sm text-n-slate-12 cursor-pointer"
          >
            {{
              t(
                'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.ASSOCIATE_CHANNELS'
              )
            }}
          </label>
        </div>

        <div v-if="associateToChannels" class="ml-6 flex flex-col gap-3">
          <p class="text-xs text-n-slate-11">
            {{
              t(
                'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANNEL_SELECTION.DESCRIPTION'
              )
            }}
          </p>

          <!-- Channel selection controls -->
          <div class="flex items-center gap-2 text-xs">
            <button
              type="button"
              class="text-n-blue-text hover:underline"
              @click="selectAllChannels"
            >
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANNEL_SELECTION.SELECT_ALL'
                )
              }}
            </button>
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span class="text-n-slate-11">{{ '|' }}</span>
            <button
              type="button"
              class="text-n-blue-text hover:underline"
              @click="clearAllChannels"
            >
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANNEL_SELECTION.DESELECT_ALL'
                )
              }}
            </button>
          </div>

          <!-- Channel list -->
          <div class="flex flex-col gap-2 max-h-40 overflow-y-auto">
            <div
              v-for="channel in availableChannels"
              :key="channel.id"
              class="flex items-center gap-2"
            >
              <input
                :id="`channel-${channel.id}`"
                :checked="selectedChannelIds.includes(channel.id)"
                type="checkbox"
                class="w-4 h-4"
                @change="handleChannelToggle(channel.id)"
              />
              <label
                :for="`channel-${channel.id}`"
                class="text-sm text-n-slate-12 cursor-pointer"
              >
                {{ getChannelDisplayName(channel) }}
              </label>
            </div>
          </div>

          <p class="text-xs text-n-slate-11">
            <strong
              >{{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANNEL_SELECTION.NOTE'
                ).split(':')[0]
              }}{{ ':' }}</strong
            >
            {{
              t(
                'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANNEL_SELECTION.NOTE'
              ).split(':')[1]
            }}
          </p>
        </div>
      </div>
    </div>

    <input
      ref="fileInput"
      type="file"
      accept="text/csv"
      class="hidden"
      @change="handleFileChange"
    />
  </Dialog>
</template>
