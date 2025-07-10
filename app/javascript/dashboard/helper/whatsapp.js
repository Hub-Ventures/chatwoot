import InboxesAPI from '../api/inboxes';

export const getWhatsAppTemplates = async inboxId => {
  try {
    const response = await InboxesAPI.getWhatsappTemplates(inboxId);
    return response.data;
  } catch (error) {
    throw new Error(error);
  }
};
